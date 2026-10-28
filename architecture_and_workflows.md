# Propuesta de Arquitectura y Flujos Operativos: Aplicación Logistics "Campos"
**Sistema Modular de Desconsolidación de Contenedores y Patio de Maniobras**

---

## 1. Visión General del Sistema
La aplicación **Soluciones Campos** es una plataforma web logística diseñada para gestionar dos módulos de operación portuaria y terrestre de bajo acoplamiento pero alta integración:
1. **Módulo de Desconsolidación (Desycon) y Despacho:** Manejo de mercancía suelta asociada a un Conocimiento de Embarque Master (`MasterBl`), vaciado de contenedores y entrega a transporte terrestre.
2. **Módulo de Patio de Maniobras y Resguardo:** Control de ingreso, posicionamiento, traspaleo, resguardo de contenedores independientes y salida mediante pases de garita (`GatePass` / `Eir`).

---

### 2. Flujo de Desconsolidación e Ingreso

```
[Ingreso MBL/Excel] ──> [Generación EIR + QR] ──> [Escaneo en Caseta / Asignación Ubicación]
                                                                  │
[Bodega / Registro Ubicación] <── [Desycon + Registro Fotos] <─── [Notificación Grúa]
            │
[Estatus Contenedor: Vacío] ──> [Notificación Grúa a Patio Vacíos] ──> [Asignación Transporte Vacío]
```

1. **Captura de MBL:**
   * El cliente o personal interno registra el MBL.
   * Carga masiva mediante plantilla de Excel con la relación de contenedores y el desglose de carga (rollos o lingotes de acero).
2. **Control de Acceso (EIR & QR):**
   * Emisión automática del PDF EIR con un código QR único.
   * Al arribo, caseta escanea el QR $\rightarrow$ Redirección a la vista de detalle del contenedor.
   * Registro de fotos de entrada, captura de movimiento y notificación automática a la **Grúa** con la ubicación asignada en patio.
3. **Traslado a Desycon:**
   * Personal interno genera listas de trabajo específicas para la grúa.
   * Movimiento del contenedor del patio al área de **Desycon** (Desconsolidación).
4. **Proceso de Desconsolidación y Bodega:**
   * Captura de evidencia fotográfica agrupada por etapas:
     * *Apertura*
     * *Desconsolidación*
     * *Contenedor Vacío*
   * **Maniobra de Montacargas:**
     * Descarga de mercancía y colocación en bodega (agrupada por contenedor origen).
     * Registro de ubicación en bodega mediante **etiquetas QR adheribles** por bulto/lote de acero.
5. **Cierre de Contenedor:**
   * Tras completar el vaciado, el contenedor cambia automáticamente a estatus `Vacío`.
   * Generación de orden de movimiento y notificación a la grúa para traslado a zona de vacíos.
   * Programación y asignación de transporte para retiro del contenedor vacío.

---

### 3. Flujo de Despacho de Mercancía

```
[Solicitud Cliente (Destino)] ──> [Asignación Transportista] ──> [Generación QR Transportista]
                                                                         │
[Carga a Camión (Montacargas)] <── [Escaneo QR en Caseta] <──────────────┘
            │
[Despacho Completo del MBL?] ──> (Sí) ──> [Generación Automática de Servicio] ──> [Facturación Manual]
```

1. **Instrucción de Despacho:**
   * El cliente registra la solicitud en la app especificando cantidad de mercancía y destino nacional.
2. **Asignación de Transporte:**
   * Personal interno asigna la empresa transportista.
   * El transportista ingresa al portal, consulta el viaje asignado y genera su pase de acceso QR.
3. **Carga y Salida:**
   * Escaneo del QR en caseta e ingreso del transporte.
   * Notificación enviada al **Montacargas** en su vista especializada, indicando mercancía (lectura con QR adherible) y transporte asignado.
   * Carga del material y liberación del camión.
4. **Facturación Unificada:**
   * El sistema monitorea el despacho acumulado de la mercancía de un MBL.
   * **Condición de cierre:** Cuando se despacha la *totalidad* de la mercancía perteneciente a todas las unidades de un MBL, el sistema **crea automáticamente el Servicio Único**.
   * La facturación se ejecuta de forma manual en una fase posterior.

### Captura inicial de mercancías

La mercancía se registra en un manifiesto asociado a un cliente. Si procede de un contenedor, se asocia al contenedor y hereda la relación con su MBL; si es carga general, se registra directamente para el cliente, sin MBL ni contenedor.

El catálogo inicial de embalajes distingue unidades individuales (pallet y rollo) de cantidades agrupadas (caja). Cada pallet y rollo se captura individualmente y requiere su peso; el QR interno es opcional para ambos. El identificador de origen es opcional y aplica a cualquier embalaje. Las cajas se registran en líneas agrupadas por descripción y cantidad, sin peso por unidad.

Los registros pueden capturarse manualmente o importarse desde Excel de forma transaccional. Al confirmar la captura, sus líneas quedan bloqueadas para edición. El ciclo `draft → confirmed` se gestiona con AASM; un administrador puede reabrir la captura. Cada confirmación y reapertura se registra en `cargo_manifest_events` (usuario, fecha, estado origen y destino, inmutable) y el historial solo lo ve el administrador. Los cambios de líneas no se auditan. Esta etapa no registra recepción verificada ni descuentos por despacho; esos procesos usarán este registro como base en una fase posterior.

### Ubicaciones en bodega

La bodega tiene 4 naves con ubicaciones de piso numeradas del 1 al 16 (la nave 1 no tiene la ubicación 8; en el mapa se dibuja un espacio libre entre la 4 y la 5). Cada ubicación se divide en las subdivisiones A, B y C, con capacidad aproximada de 3 contenedores; no hay estado "llena", la ocupación se calcula con las líneas ubicadas. Cada ubicación tiene una etiqueta QR (`qr_token`) que abre su detalle.

Solo las líneas de una captura confirmada se pueden ubicar (`captured → stored`, AASM), por administrador o montacargas, también para reubicar. Cada ubicación o reubicación se registra de forma inmutable en `cargo_item_movements` (origen, destino, usuario y fecha). Una línea de cajas agrupadas se ubica completa en una sola ubicación. El catálogo se carga con `bin/rails db:seed:warehouse` y el mapa 3D está en `/warehouse`.

---

### 4. Flujo Diferenciado: Patio de Maniobras (Resguardo y Traspaleo)

Este módulo opera de forma **independiente** del flujo de desconsolidación:

*   **Servicios prestados:** Resguardo, almacenaje temporal, traspaleo de contenedor a contenedor y reubicaciones.
*   **Gestión por Cliente:** El cliente solicita desde el portal el ingreso, salida o traspaleo de contenedores, generando sus respectivos pases QR.
*   **Control en Garita:** El QR del pase contiene un enlace web absoluto que abre directamente el detalle del pase al escanearlo con la cámara nativa del dispositivo. Si no hay sesión, se solicita iniciar sesión y luego se vuelve al pase; solo Seguridad o administración pueden continuar. En la consola `/gate` también se puede escanear con la cámara del navegador o capturar manualmente el token. La cámara integrada requiere un navegador compatible, permiso explícito y HTTPS fuera de localhost; si no está disponible, el formulario manual permanece visible.
*   **Evidencia antes de confirmar:** En el detalle del pase, Garita puede cargar hasta 30 fotos JPG, PNG o WebP (10 MB máximo cada una). Las fotos quedan temporalmente en el pase vigente y solo se transfieren al historial inmutable del movimiento al confirmar; si el pase vence o se cancela, las fotos temporales se eliminan.
*   **Ingreso a patio:** Garita busca y elige una posición exacta habilitada y libre, no usa un menú desplegable. La búsqueda prioriza la sección/área de la asignación; después, las secciones activas del MBL y, por último, las áreas activas del cliente, sin ocultar otras posiciones libres compatibles. Un contenedor de 40 pies reserva su bahía ancla impar y la contigua en la misma fila y nivel. Un nivel superior al 1 solo se ofrece y acepta si hay un contenedor en el nivel inferior bajo toda la huella (ambas bahías en 40 pies); un contenedor que soporta a otro no puede salir hasta retirar el de arriba.
*   **Mapa 3D del patio:** Las posiciones ocupadas se muestran con una geometría opaca de contenedor (nervaduras y esquineros) distinta de los cubos translúcidos de posiciones libres. Al seleccionar un contenedor se muestran su número, tamaño y ubicación. Cada cliente puede tener un `container_color` (asignable en su detalle); sus contenedores, o los de sus MBL, se dibujan con ese color, y sin color se usa el rojo predeterminado.
*   **Salida y traspaleo:** La salida requiere una ubicación actual y la libera en la misma transacción. El traspaleo registra el cambio entre vehículos sin ocupar una posición de patio.
*   **Historial y ocupación:** Cada operación conserva un movimiento inmutable con contenedor, pase, usuario, tipo, origen/destino, fotos y estado de carga cuando aplica. En el detalle del contenedor, cada operación aparece en una sección colapsable cerrada por defecto; la galería se carga de forma diferida al abrirla. La ubicación física actual se mantiene separada del estado de carga.
*   **Cobro Operativo:**
    *   Generación **automática** de un registro de servicio cobrable por cada movimiento individual:
        *   *Camión $\rightarrow$ Piso*
        *   *Piso $\rightarrow$ Camión*
        *   *Traspaleo*
        *   *Almacenaje (Días/Tarifa)*
        *   *Reubicación*

---
