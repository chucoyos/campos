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
*   **Control en Garita:** El QR del pase contiene un enlace web absoluto que abre directamente el detalle del pase al escanearlo con la cámara nativa del dispositivo. Si no hay sesión, se solicita iniciar sesión y luego se vuelve al pase; solo Seguridad o administración pueden continuar. En la consola `/gate` también se puede escanear con la cámara del navegador o capturar manualmente el token. Ingreso y salida requieren escanear el mismo pase al entrar y al salir; tras el primer registro, el pase deja de vencer por tiempo y no se puede cancelar hasta cerrar el ciclo. Traspaleo conserva una sola validación. La cámara integrada requiere un navegador compatible, permiso explícito y HTTPS fuera de localhost; si no está disponible, el formulario manual permanece visible.
*   **Evidencia antes de confirmar:** En el detalle del pase, Garita puede cargar hasta 30 fotos JPG, PNG o WebP (10 MB máximo cada una). Las fotos quedan temporalmente en el pase vigente y solo se transfieren al historial inmutable del movimiento al confirmar; si el pase vence o se cancela, las fotos temporales se eliminan.
*   **Ingreso a patio:** Garita busca y elige una posición exacta habilitada y libre, no usa un menú desplegable. La búsqueda prioriza la sección/área de la asignación; después, las secciones activas del MBL y, por último, las áreas activas del cliente, sin ocultar otras posiciones libres compatibles. Un contenedor de 40 pies reserva su bahía ancla impar y la contigua en la misma fila y nivel. Un nivel superior al 1 solo se ofrece y acepta si hay un contenedor en el nivel inferior bajo toda la huella (ambas bahías en 40 pies); un contenedor que soporta a otro no puede salir hasta retirar el de arriba.
*   **Ingreso y colocación por la grúa:** En el primer escaneo, Garita registra la entrada del camión y reserva la posición elegida mediante una tarea de grúa (`WorkOrder`, AASM `pendiente → completada | cancelada`). El contenedor no tiene posición en patio hasta que la grúa concluye la tarea; entonces se registra el movimiento y el pase queda abierto hasta el segundo escaneo al salir. Una posición reservada bloquea la huella (no se ofrece ni se acepta de nuevo), pero no sirve de soporte para apilar hasta que el contenedor esté físicamente colocado; tampoco se puede retirar el contenedor de abajo mientras haya una reserva encima. Un contenedor con tarea pendiente no admite otro movimiento.
*   **Consola de la grúa (`/crane`):** Los usuarios con rol `grua` (y el administrador) ven en tiempo real, vía Turbo Streams, las tareas pendientes con tipo de movimiento, contenedor, origen y destino, y datos del transporte (empresa, operador, placas, camión sencillo o full). Al pulsar "Concluir tarea", `CraneTaskService` revalida el destino con bloqueo de filas, fija `current_yard_slot`, pasa el contenedor de Activo a Lleno al ingresar y de Vacío a Entregado al salir de un MBL, registra el movimiento inmutable con las fotos del pase y cierra la tarea. Los eventos de montacargas permanecen separados.
*   **Mapa 3D del patio:** Las posiciones ocupadas se muestran con una geometría opaca de contenedor (nervaduras y esquineros) distinta de los cubos translúcidos de posiciones libres. Al seleccionar un contenedor se muestran su número, tamaño y ubicación. Cada cliente puede tener un `container_color` (asignable en su detalle); sus contenedores, o los de sus MBL, se dibujan con ese color, y sin color se usa el rojo predeterminado.
*   **Salida y reacomodo:** En el primer escaneo de salida, Garita crea la tarea de carga si el contenedor está libre o un plan de movimiento si hay contenedores encima. La misma orquestación permite que Grúa solicite un reacomodo independiente de un contenedor bloqueado. En este caso, el destino final se elige y reserva al crear el plan; la reserva impide colisiones, pero no cuenta como ocupación física ni como soporte. En ambos flujos se mueve un bloqueador superior a la vez a un destino libre y soportado; tras cada confirmación el sistema recalcula el siguiente y, cuando se despeja el objetivo, programa la carga o el reacomodo final. Si el destino reservado deja de ser válido, el plan permanece visible para cambiarlo y reintentar; si no hay bloqueador movible, se puede reintentar al cambiar la disponibilidad del patio. Los reacomodos independientes aparecen agrupados con sus movimientos subordinados en `/crane`; la búsqueda usa el número y excluye contenedores con tarea o plan pendiente. Si un plan de salida se cancela, los movimientos físicos ya confirmados permanecen en el historial y el camión puede salir sin el contenedor solicitado. Tras completar la carga, Seguridad escanea nuevamente el pase y confirma visualmente que el contenedor correcto salió; el pase y el movimiento se cierran aunque la verificación visual detecte una discrepancia, que se resuelve por radio y no deshace el historial. El traspaleo registra el cambio entre vehículos en un solo escaneo, sin ocupar una posición de patio.
*   **Programación (lista de trabajo de desconsolidación):** El administrador abre `/work_schedules`, elige un MBL con contenedores en patio, ajusta con casillas los contenedores que se moverán a DESYCON (bloques `1CFS`, `2CFS` y `3CFS`) y define la fecha de ejecución (el día anterior o el mismo día para ejecutarla en la noche). `WorkScheduleService` crea de forma atómica una tarea de reacomodo (`WorkOrder`) por contenedor libre, con una posición sugerida y reservada en DESYCON; si el contenedor está bloqueado, crea un `MovementPlan` agrupado que mueve un bloqueador a la vez (nunca hacia DESYCON) antes del movimiento final. En `/crane` la grúa alterna entre las pestañas "Movimientos normales" y "Programación"; esta última agrupa las tareas por programación, permite cambiar la posición dentro de DESYCON y confirma cada movimiento individualmente. Al confirmar se actualiza la ubicación del contenedor y se libera su posición anterior; las tareas programadas solo aceptan destinos en DESYCON. Solo el administrador cancela una programación y esta se cierra automáticamente cuando no quedan tareas ni planes pendientes.
*   **Historial y ocupación:** Cada operación conserva un movimiento inmutable con contenedor, pase, usuario, tipo, origen/destino, fotos y estado de carga cuando aplica. En el detalle del contenedor, cada operación aparece en una sección colapsable cerrada por defecto; la galería se carga de forma diferida al abrirla. La ubicación física actual se mantiene separada del estado de carga.
*   **Cobro Operativo:**
    *   Generación **automática** de un registro de servicio cobrable por cada movimiento individual:
        *   *Camión $\rightarrow$ Piso*
        *   *Piso $\rightarrow$ Camión*
        *   *Traspaleo*
        *   *Almacenaje (Días/Tarifa)*
        *   *Reubicación*

---
