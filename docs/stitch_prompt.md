# PROMAX MES — Prompt maestro para Google AI Studio / Stitch

> **Cómo usarlo:** copia el bloque **PROMPT PRINCIPAL** completo y pégalo en Stitch (stitch.withgoogle.com) o en AI Studio (Gemini, modo Canvas) para generar la aplicación entera. Si la herramienta genera una pantalla a la vez, pega el prompt principal seguido de la sección **PANTALLA N** que quieras obtener.
>
> El foco de este prompt son las **funcionalidades de la interfaz**: campos, validaciones, estados, interacciones y comportamientos reales que debe soportar cada pantalla (basado en la especificación técnica aprobada del MVP).

---

## PROMPT PRINCIPAL (copiar desde aquí)

Eres un diseñador UI/UX senior especializado en aplicaciones industriales de manufactura. Genera una **aplicación web responsiva** llamada **PROMAX**, un sistema MES (Manufacturing Execution System) de control de piso para plantas de manufactura metalmecánica (corte, estampado, soldadura, ensamble). Genera todas las pantallas descritas abajo con datos de ejemplo realistas.

### Contexto de uso (define todas las decisiones de diseño)

- Se usa en **tablets de 10–13" montadas en kioscos de planta** y en monitores de oficina para los módulos administrativos. Operarios con guantes → **objetivos táctiles mínimo 48×48 px**, botones grandes, texto base ≥16 px, iconos con etiqueta de texto.
- Conexión intermitente en planta → la UI comunica el estado con un banner global: `🟡 Sin conexión · N pendientes` + botón **"Sincronizar ahora"**.
- Datos en tiempo real vía WebSocket: paros, producción, alertas Andon y KPIs se actualizan en vivo sin recargar.
- Dos ambientes visuales: **kiosco** (operario: tarjetas grandes, alto contraste, flujos lineales de 2–3 pasos) y **admin** (supervisor/admin: tablas densas, filtros, dashboards).

### Usuarios y roles (el menú lateral se filtra por rol)

| Rol | Acceso |
|-----|--------|
| Operario | Kiosco de centro de trabajo |
| Supervisor | + Trabajo en Proceso, Dashboard, Orden Manual |
| Admin | Todo: Usuarios, Usuarios×Centro, Configuración |

### Identidad visual

- Logo: **ProMax** — "Pro" en azul, "Max" en verde, negrita itálica, seguido del subtítulo "MES de Control de Piso".
- Paleta exacta: primario `#3860B2`, header `#616161`, fondo `#EDEDED`, tarjetas `#FFFFFF`, verde éxito `#57A84B`, rojo `#FF0000`, teal `#2BA8AD`, cyan `#48BBDD`, navy `#0D2535`, texto `#1C1C1C`, texto secundario `#62686C`, bordes `#C8C4C0`.
- Tipografía sans-serif moderna (Segoe UI / Inter), jerarquía clara de pesos.
- Estilo: tema claro industrial; tarjetas con borde redondeado 8–12 px y sombra suave; chips/badges de estado (🟡 pendiente / 🟢 OK / 🔴 error); botón principal verde grande con efecto de profundidad; tablas con encabezado azul-gris claro.

### Shell / Navegación (envuelve todas las pantallas logueadas)

- **Header**: logo ProMax a la izquierda; centro: nombre del usuario, rol y centro activo; derecha: chip Online/Offline, icono "Modo guiado" (toggle de ayuda paso a paso), campana de notificaciones Andon con badge contador, menú de usuario (Perfil / Cerrar sesión).
- **Sidebar colapsable** (en tablet se colapsa a riel de iconos): Centros de Trabajo · Trabajo en Proceso · Dashboard · Orden Manual · Usuarios · Usuarios × Centro · Configuración.
- Banner offline global, toasts de información/error, y toast Andon persistente con indicador de sonido.
- Accesibilidad WCAG 2.1 AA: contraste ≥4.5:1, focus visible, etiquetas ARIA, navegación completa por teclado. Idioma español (arquitectura lista para i18n ES/EN).

---

### PANTALLA 1 — Login (`/login`)

- Fondo industrial oscuro con overlay; tarjeta central translúcida con el logo ProMax arriba.
- Campos: **Cédula** (numérico, 6–20 dígitos, teclado numérico) y **Contraseña** (mínimo 8 caracteres, botón ojo para mostrar/ocultar).
- Botón "Ingresar" ancho completo. Validaciones: cédula solo dígitos; mensajes de error inline "Credenciales inválidas" / "Usuario inactivo" / "Cuenta bloqueada (5 intentos)".
- Estados: reposo → cargando (spinner dentro del botón, se deshabilita) → redirige al kiosco.
- Botón "¿Olvidaste tu contraseña?" → modal con email → mensaje de confirmación genérico (no revela si el email existe).

### PANTALLA 2 — Selección de Centro y Órdenes (kiosco operario, `/kiosk`)

- **Header de pantalla**: título "CENTRO DE TRABAJO" + nombre del centro activo (ej. "10024 — GUILLOTINA EXCENTRICA"), usuario logueado, botones: Actualizar, Info turnos, Salir.
- **Barra de filtros** (todos obligatorios antes de operar): Turno (T1/T2/T3), Centro de trabajo (código + nombre), No. Orden con **botón de escáner de código de barras** al lado, Operación (10/20/30), toggle grande **"ÓRDENES MÚLTIPLES"**.
- Si el centro es de corte CNC (ej. plasma): aparece un **panel "NESTEO"** con dropdown de archivos CNC activos (ej. `513314_PROARC01.CNC`); elegir un nesteo pre-selecciona todas sus órdenes.
- **Tabla de órdenes aprobadas**: N° Orden hija (formato `PMF-OPH-00028732` + alias corto), Línea, Referencia del material, RQI, Cantidad pendiente (destacada en grande), Op, Fecha, columna **Acción** (ℹ ver detalle en modal, ✏ ejecutar).
- Selección por fila con checkbox grande; filas seleccionadas se resaltan en verde con borde izquierdo; contador "N seleccionadas · cantidad total".
- **Footer**: botón "Cancelar" (secundario) y botón circular/verde grande **"INICIAR ▶"** — deshabilitado hasta seleccionar ≥1 orden (individual, múltiple o nesteo).
- Al iniciar: POST `iniciar` → navega a Operaciones. Al cambiar centro: limpia la selección.

### PANTALLA 3 — Registro de Operación (`/kiosk/:ordenId/operaciones`)

- **Header de solo lectura**: usuario, centro, orden padre/hija, item y cantidades (ejecutar / pendiente).
- **Galería horizontal** de operaciones de la orden con la actual destacada.
- Formulario: **Cantidad de operarios** (stepper 1–20); si es >1 → zona de **escaneo de cédula de ayudantes**: input de escáner + lista de chips con el nombre y botón ✕; valida: cédula existe, usuario activo, asignado al centro, no duplicado y no es el usuario actual.
- **Tipo de actividad inicial** (dropdown) → **Código de operación** (dropdown dependiente, filtrado por el tipo).
- Botón primario **"Validar e iniciar"**: envía el payload; si la actividad = PRODUCCIÓN navega a Producción; si = PARO navega a Paros. Errores de validación marcados por campo.
- Catálogos cacheados 24 h (funciona offline tras primera carga).

### PANTALLA 4 — Control de Paros (`/kiosk/:ordenId/paros`)

- **Cronómetro grande en vivo** del paro en curso (formato HH:MM:SS) que **sobrevive la recarga** de la página.
- Formulario "Nuevo paro": **Tipo de paro** (dropdown), **Código de operación** (dependiente), **Motivo** (textarea opcional 200 chars), **Lote** (obligatorio, pre-llenado con el último usado).
- **Historial de paros del turno** (tabla): hora inicio, hora fin, duración, tipo, motivo; se actualiza en vivo por WebSocket.
- Acciones: **"Generar paro"** (cierra el paro actual y encadena uno nuevo ya prellenado) y **"Iniciar producción"** (cierra el paro y navega a Producción).
- Toast de IA: "¿Paro detectado? Confirmar" cuando un sensor sugiere un tipo de paro.
- Crítico offline: cronómetro en localStorage; los paros se encolan (IndexedDB) y sincronizan por lotes al reconectar.

### PANTALLA 5 — Control de Producción (`/kiosk/:ordenId/produccion`)

- **Header KPI en tiempo real**: OEE (verde ≥85 / rojo <60 / teal intermedio), Disponibilidad, Desempeño, Calidad, y **Objetivo hora-hora**: barra de progreso verde/roja comparando piezas acumuladas vs meta por hora transcurrida.
- Cronómetro del bloque de producción en curso (persiste al recargar).
- Formulario: **Lote** (pre-llenado), **Piezas conformes** (stepper grande, ≤ cantidad pendiente), **Piezas no conformes** (stepper; si >0 aparece **Motivo de rechazo** obligatorio), Tipo y Código de actividad siguiente (para cuál va a ser el próximo estado).
- **Historial de bloques del turno** (tabla en vivo).
- Botón **"Parar producción"**: guarda el bloque → navega a Paros con la actividad siguiente ya preseleccionada.

### PANTALLA 6 — Trabajo en Proceso / WIP (`/admin/trabajo-en-proceso`)

- **Sidebar de filtros**: planta, líneas (multi), centros (multi), turno, rango de fechas, estado sync (PENDING/OK/ERROR), tipo de entidad (Producción/Paros/Entregas/Rechazos).
- **Tabla densa tipo AG Grid** (ordenable/filtrable/paginada): Fecha-hora, Planta, Línea, Centro, Turno, OP, Tipo, Good, Scrap, **badge Estado sync** (🟡 PENDING / 🟢 OK / 🔴 ERROR), Último intento, GUID S/4HANA, Mensaje de error.
- **Toolbar**: "Reintentar seleccionados", "Reintentar todos (filtrados)", "Exportar CSV". Acción por fila: "Ver detalle" → modal con payload completo y respuesta de S/4HANA.
- Las filas cambian de estado en vivo (WebSocket) con animación de actualización.

### PANTALLA 7 — Dashboard Admin (`/admin/dashboard`)

- **Filtros globales** en header: planta, línea, turno, rango (hoy / ayer / 7d / 30d).
- **Grid de widgets** (todo en tiempo real): Minutos de paro por centro (barras horizontales), Pareto de códigos de paro (barras + línea acumulada 80%), OEE por centro/turno (gauge + sparkline de 7 días), Panel de OPs en proceso (tabla con semáforo de estado), Andon activos (lista de alertas con prioridad).
- Botón exportar: PNG / PDF / CSV. Cuando entra una alerta Andon: toast + sonido + badge.

### PANTALLA 8 — Usuarios (`/admin/usuarios`)

- Tabla CRUD paginada con búsqueda: ID (cédula), Nombre, Email, Teléfono, Rol (badge de color), Activo (toggle en línea), Centros (chips).
- Modal crear/editar con validaciones: cédula única y regex, email único y válido, contraseña solo en creación/reset (mín 8).
- Acciones: reset password, desactivar (soft-delete), pestaña "Centros" para asignar centros.

### PANTALLA 9 — Usuarios × Centro (`/admin/usuarios-centros`)

- **Matriz**: usuarios en filas × centros en columnas, checkboxes grandes para asignar/desasignar con un click.
- Acciones masivas: asignación bulk a un usuario y "copiar de otro usuario".

### PANTALLA 10 — Orden Manual (`/admin/orden-manual`)

- Formulario de 21 campos organizado en **secciones colapsables**: Identificación (OP padre con validación async contra S/4HANA, número único, operación), Fechas (inicio ≥ hoy, fin ≥ inicio), Cantidades (ejecutar >0, pendiente auto, completa, retrabajo, rechazos), Clasificación (clase OP: ÚNICA/COMPONENTE/RETRABAJO), Asignación (centro con autocomplete, item con lookup de material S/4, bodega, línea), Extras (referencias, notas).
- Botones: **Guardar**, **Clonar**, **Guardar borrador**. Errores por campo con resumen arriba.

---

### Comportamientos transversales (aplicarlos a todas las pantallas)

1. **Offline-first**: colas IndexedDB para paros, producción e inicios de orden; al reconectar, sincronización automática por lotes + banner con pendientes. Cronómetros sobreviven recargas.
2. **Tiempo real**: paros, producción, sync y Andon llegan por WebSocket y actualizan tablas/KPIs sin recargar; toasts para eventos.
3. **Permisos**: rutas y botones ocultos según rol; el operario solo ve su centro/orden.
4. **Responsive**: breakpoint 768 px colapsa sidebar a riel; kiosco optimizado para tablet horizontal.
5. **Validación inline** en todos los formularios (feedback inmediato por campo, sin alert() nativos).

**Empieza generando el shell + la PANTALLA 2 (Selección de Centro y Órdenes)** — es la de mayor uso — y luego continúa con 1, 3, 4 y 5 en ese orden.

(Copia hasta aquí)
