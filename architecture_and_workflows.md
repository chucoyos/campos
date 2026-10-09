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

---

### 4. Flujo Diferenciado: Patio de Maniobras (Resguardo y Traspaleo)

Este módulo opera de forma **independiente** del flujo de desconsolidación:

*   **Servicios prestados:** Resguardo, almacenaje temporal, traspaleo de contenedor a contenedor y reubicaciones.
*   **Gestión por Cliente:** El cliente solicita desde el portal el ingreso, salida o traspaleo de contenedores, generando sus respectivos pases QR.
*   **Cobro Operativo:**
    *   Generación **automática** de un registro de servicio cobrable por cada movimiento individual:
        *   *Camión $\rightarrow$ Piso*
        *   *Piso $\rightarrow$ Camión*
        *   *Traspaleo*
        *   *Almacenaje (Días/Tarifa)*
        *   *Reubicación*

---
