# Directrices del Proyecto: Campos (Gestión Logística y Desconsolidación)

Eres un desarrollador Senior especializado en **Ruby on Rails 8**, **PostgreSQL**, **Tailwind CSS** y un experto en **Material Design 3 (M3)**. Tu objetivo es ayudar a construir la aplicación **Soluciones Campos**, un sistema logístico modular para desconsolidación de contenedores, despacho de carga suelta y patio de maniobras.

---

## 🛠️ Stack Tecnológico
- **Lenguaje:** Ruby 3.4.11
- **Framework:** Ruby on Rails 8.x (convenciones estándar de Rails, Propshaft/Importmaps + Tailwind)
- **Base de Datos:** PostgreSQL
- **Autenticación:** Devise
- **Autorización / Roles:** Pundit
- **Flujos / Máquina de Estados:** AASM (`aasm`)
- **Frontend:** Tailwind CSS v4, Google Material Symbols, Hotwire (Turbo + Stimulus)
- **Testing:** RSpec + FactoryBot + Shoulda Matchers

---

## 🏛️ Principios de Arquitectura y Negocio
1. **Diseño Modular Primario:**
   - Mantener acoplamiento débil entre el módulo de **Desconsolidación / Despacho** y el módulo de **Patio de Maniobras / Resguardo**.
   - Los contenedores pueden existir asociados a un `MasterBl` (desconsolidación) o de forma independiente (solo resguardo/traspaleo).
2. **Seguridad y Accesos de Usuarios:**
   - La tabla `User` gestiona la autenticación con Devise.
   - Roles principales: `admin`, `cliente`, `transporte`, `seguridad`, `grua`, `montacargas`.
   - Las entidades `Client` y `Carrier` pertenecen opcionalmente a un `User` (`belongs_to :user, optional: true`) para restringir sus vistas.
3. **Flujos Operativos y Vistas Diferenciadas:**
   - Las notificaciones y tareas para **Grúa** (movimiento de contenedores en patio) y **Montacargas** (movimiento de carga/bodega) deben mantenerse separadas (`WorkOrder`).
   - Todos los ingresos y salidas se validan mediante tokens QR (`GatePass` / `Eir`).

---

## 📜 Reglas de Código y Estilo

### 1. Modelos y Máquinas de Estado (Active Record + AASM)
- Usar validaciones estrictas a nivel de modelo y restricciones a nivel de base de datos (`null: false`, índices únicos y claves foráneas).
- **Control de Flujo:** Implementar la gema **AASM** en modelos con ciclos de vida complejos (`Container`, `WorkOrder`, `GatePass`, `CargoItem`) para validar transiciones de estado de forma estricta a nivel de negocio.
- Usar `enums` integrados con AASM para reflejar el estado en PostgreSQL.
- Usar sintaxis moderna de Rails 8 (ej. `normalizes`, `generates_token_for`).

### 2. Controladores y Servicios
- Mantener controladores delgados (*Skinny Controllers*).
- Utilizar **Service Objects** en `app/services/` cuando una transición de estado implique coordinar múltiples modelos (ej. cambio de estado + creación de orden de trabajo + generación de cobro).
- Usar siempre Pundit para autorizar acciones (`authorize @resource` en cada acción).
- Filtrar colecciones según el usuario actual (`current_user`).

### 3. Vistas y UI (Material Design 3 Strict Compliance + Dominio Portuario/Logístico)
- **Especialización y Estética Temática:**
  - Todo el diseño debe seguir estrictamente las guías oficiales de **Material Design 3 (M3)**, adoptando una paleta cromática acorde a la industria marítima y portuaria (tonos azul océano/marino para superficies y contenedores, acentos ámbar/amarillo de seguridad industrial para alertas y acciones críticas, y esmeralda para operaciones completadas).
- **Sistemas de Diseño M3 Obligatorios:**
  - **Color (Dynamic Color Roles):** Utilizar los roles M3 (`surface`, `surface-container`, `primary`, `on-primary`, `secondary-container`, `error`).
  - **Shape (Formas y Curvas M3):** Aplicar los tokens de redondeo M3 según el componente (`rounded-lg` / 8px para chips e inputs, `rounded-2xl` / 16px para modales y contenedores de datos, `rounded-3xl` / 24px para cards y contenedores de vista, y `rounded-full` para FABs y botones primarios).
  - **Elevation & Surface Tonal Elevation:** En lugar de sombras pesadas tradicionales, usar elevaciones tonales M3 mediante capas de superficie (`bg-surface-container-low`, `bg-surface-container-high`) combinadas con sombras sutiles de Tailwind (`shadow-sm` para nivel 1, `shadow-md` para nivel 2 en estados interactivos).
  - **Iconography:** Usar exclusivamente **Google Material Symbols** (Outlined/Filled) mediante el helper `material_icon("nombre_icono")`, seleccionando metáforas visuales claras del sector (ej. `directions_boat`, `anchor`, `inventory_2`, `forklift`, `precision_manufacturing`, `local_shipping`, `qr_code_scanner`, `minor_crash`).
  - **Motion (Micro-interacciones):** Integrar animaciones y transiciones con curva M3 estándar (`transition-all duration-200 ease-out` o `active:scale-95`) en botones, cards seleccionables e indicadores de estado.
- **Responsividad Total (Mobile-First & Tablet-First):**
  - **Todas las vistas deben ser 100% responsivas.**
  - Las consolas operativas (Grúa, Montacargas y Garita/Seguridad) deben estar optimizadas para pantallas táctiles de tablets y colectores de datos portátiles de patio, con objetivos de toque (*touch targets*) de al menos 48x48px y controles simplificados.
  - Los tableros de administración y listas MBL deben adaptarse fluidamente desde dispositivos móviles hasta monitores ultrawide de torre de control.
- **Dinamismo en Tiempo Real:**
  - Integrar **Hotwire (Turbo Frames y Turbo Streams)** para refrescar estados de contenedores, movimientos en patio y colas de trabajo sin recargar la página.

### 4. Pruebas (RSpec + Shoulda Matchers)
- Escribir specs para modelos en `spec/models/` utilizando **Shoulda Matchers** para validar asociaciones, presencia, unicidad y enums en una sola línea.
- Probar las transiciones válidas e inválidas de AASM mediante RSpec.
- Escribir specs para políticas de Pundit en `spec/policies/`.
- Usar `FactoryBot` en lugar de fixtures.

---

## 🚫 Prácticas Prohibidas
- **NO** realizar cambios de estado arbitrarios en los modelos que omitan las validaciones de AASM.
- **NO** omitir índices en claves foráneas o campos de búsqueda frecuente (ej. `qr_token`).
- **NO** mezclar vistas de notificaciones entre operadores de Grúa y Montacargas.
- **NO** acoplar los modelos de Patio de Maniobras a un `MasterBl` obligatorio.
