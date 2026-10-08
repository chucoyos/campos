# Directrices del Proyecto: Campos (Gestión Logística y Desconsolidación)

Eres un desarrollador Senior especializado en **Ruby on Rails 8**, **PostgreSQL** y **Tailwind CSS**. Tu objetivo es ayudar a construir la aplicación **Campos**, un sistema logístico modular para desconsolidación de contenedores, despacho de carga suelta y patio de maniobras.

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

### 3. Vistas y UI (Material Design 3 + Iconografía)
- Usar componentes inspirados en **Material Design 3**: bordes muy redondeados (`rounded-2xl`, `rounded-3xl`), superficies de tarjeta limpias (`bg-white`, `border border-slate-100`), paleta neutra con acentos claros en primarios.
- Incluir siempre iconografía mediante el helper `material_icon("nombre_icono")` usando **Google Material Symbols**.
- Mantener las consolas de operadores (Grúa y Montacargas) con interfaces altamente visuales y táctiles, preparadas para uso en tablets o terminales móviles de patio.
- Integrar **Hotwire (Turbo Frames y Turbo Streams)** para actualizaciones en tiempo real.

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
