# PROMAX NUEVO — SPEC Técnico por Pantalla (MVP Aprobado)

> Generado a partir de `mvp_scope_approval.md` aprobado.  
> Cada pantalla: **Campos**, **Validaciones**, **Llamadas API (CAP OData V4)**, **Estados/Transiciones**, **Offline/Sync**, **Permisos**.

---

## 1. LOGIN (`/login`)

### Campos
| Campo | Tipo | Requerido | Validación |
|-------|------|-----------|------------|
| `cedula` | String(20) | Sí | Regex `^\d{6,20}$`; existe en `Usuario` activo |
| `password` | String | Sí | Mín 8 chars; bcrypt verify contra `Usuario.passwordHash` |
| `rememberMe` | Boolean | No | Extiende refresh token a 30d |

### Llamadas API
| Acción | Endpoint | Método | Payload | Respuesta |
|--------|----------|--------|---------|-----------|
| Login | `/api/v1/auth/login` | POST | `{cedula, password, rememberMe}` | `{accessToken, refreshToken, user: {id, nombre, rol, centros[]}}` |
| Refresh | `/api/v1/auth/refresh` | POST | `{refreshToken}` | `{accessToken, refreshToken}` |
| Forgot | `/api/v1/auth/forgot` | POST | `{email}` | 202 (email enviado si existe) |
| Reset | `/api/v1/auth/reset` | POST | `{token, newPassword}` | 200 |

### Estados
- `idle` → `loading` → `authenticated` (redirect `/kiosk`)
- `error`: "Credenciales inválidas" / "Usuario inactivo" / "Cuenta bloqueada (5 intentos)"

### Offline
- **No aplica** (requiere conexión para autenticar)
- Cache `user` + `centros[]` en IndexedDB para arranque rápido

### Permisos
- Público (sin token)

---

## 2. CENTROS DE TRABAJO (`/kiosk`)

### Campos (Estado Local)
| Campo | Tipo | Fuente |
|-------|------|--------|
| `turnoSeleccionado` | `Turno` | `GET /api/v1/turnos?planta={planta}&fecha={hoy}` |
| `centroSeleccionado` | `CentroTrabajo` | `GET /api/v1/centros?usuario={cedula}&turno={turno}` |
| `filtroBusqueda` | String | Input local |
| `ordenesSeleccionadas` | `OrdenProduccion[]` | Checkboxes multi-selección |
| `modoNesteo` | Boolean | Solo si `centro.grupo === 'CORTE_CALIENTE'` |
| `nesteoSeleccionado` | String | Dropdown nesteos activos |

### Llamadas API
| Acción | Endpoint | Método | Parámetros | Cache |
|--------|----------|--------|------------|-------|
| Cargar turnos | `/api/v1/turnos` | GET | `planta, fecha` | 24h (stale-while-revalidate) |
| Cargar centros | `/api/v1/centros` | GET | `usuario, turno` | 1h |
| Buscar OPs | `/api/v1/ordenes` | GET | `centro, turno, estado=Aprobada, search?, page, size` | 30s |
| Nesteos | `/api/v1/nesteos` | GET | `centro, turno` | 5 min |
| Iniciar selección | `/api/v1/ordenes/iniciar` | POST | `{ordenIds[], modo: 'individual'|'multiple'|'nesteo', nesteoId?}` | — |

### Validaciones
- Turno obligatorio antes de centros
- Centro obligatorio antes de buscar OPs
- Multi-selección: `ordenesSeleccionadas.length > 0` y coincide `cantEjecutar` vs `cantPendiente` sumadas
- Nesteo: auto-selecciona todas las OPs del nesteo; botón "Iniciar" habilitado si hay ≥1

### Estados UI
- `SELECTING_TURNO` → `SELECTING_CENTRO` → `LISTING_ORDENES` → `SELECTING_ORDENES` → `CONFIRMING` → `NAVIGATE_OPERACIONES`

### Offline
- Turnos, centros, nesteos: **cache first** (IndexedDB)
- Búsqueda OPs: **network first** → fallback cache (últimas 50)
- Iniciar selección: **offline queue** (`pendingIniciarOrden`) → sync al recuperar conexión

### Permisos
- `Operario`, `Supervisor`, `Admin` (solo centros asignados en `UsuarioCentro`)

---

## 3. OPERACIONES (`/kiosk/:ordenId/operaciones`)

### Campos (Formulario)
| Campo | Tipo | Requerido | Validación | Fuente |
|-------|------|-----------|------------|--------|
| `cantidadOperarios` | Integer (1–20) | Sí | ≥1; ≤ max configurado por centro | Input + stepper |
| `operariosAyudantes` | `Usuario[]` | Si `cantidadOperarios > 1` | Cada ayudante: escaneo cédula → existe en `Usuario`, `activo=true`, `UsuarioCentro` incluye `centroSeleccionado`, **no es el usuario logueado** | Escáner barcode / input manual |
| `tipoActividadInicial` | `TipoActividad` | Sí | Dropdown filtrado por `centroSeleccionado` | `GET /api/v1/tipos-actividad?centro={centro}` |
| `codigoOperacion` | `CodigoOperacion` | Sí | Filtrado por `tipoActividadInicial` | `GET /api/v1/codigos-operacion?tipoActividad={id}` |

### Datos de Solo Lectura (Header)
| Dato | Fuente |
|------|--------|
| Usuario logueado | `AuthContext.user.nombre` |
| Centro de trabajo | `centroSeleccionado.nombre` |
| Orden (Padre/Hija, Item, Cantidades) | `OrdenProduccion` cargada vía `ordenId` |
| Galería operaciones | `GET /api/v1/ordenes/{id}/operaciones` |

### Llamadas API
| Acción | Endpoint | Método | Payload |
|--------|----------|--------|---------|
| Cargar operaciones | `/api/v1/ordenes/{id}/operaciones` | GET | — |
| Validar e iniciar | `/api/v1/ordenes/{id}/iniciar-produccion` | POST | `{cantidadOperarios, operariosAyudantes[], tipoActividad, codigoOperacion}` |

### Validaciones
- Todos los campos `*` obligatorios
- `operariosAyudantes` únicos, no incluyen usuario actual
- `codigoOperacion` pertenece a `tipoActividadInicial`

### Transición
- Éxito → `tipoActividadInicial === 'PARO'` → `/kiosk/:ordenId/paros`
- Éxito → `tipoActividadInicial === 'PRODUCCION'` → `/kiosk/:ordenId/produccion`

### Offline
- Catálogos (`TipoActividad`, `CodigoOperacion`): **cache first** (24h)
- Iniciar: **offline queue** (`pendingIniciarProduccion`) → sync

### Permisos
- `Operario`, `Supervisor`, `Admin` (solo su centro/orden)

---

## 4. CONTROL DE PAROS (`/kiosk/:ordenId/paros`)

### Estado Local (React State + Persistencia)
| Variable | Tipo | Persistencia |
|----------|------|--------------|
| `parosActual` | `RegistroParo` (en curso) | `localStorage` + `IndexedDB` (key `paros:{ordenId}:current`) |
| `historialParos` | `RegistroParo[]` | `IndexedDB` (key `paros:{ordenId}:history`) |
| `cronometroActivo` | Boolean | `localStorage` |
| `horaInicioParo` | ISO String | `localStorage` |
| `duracionAcumulada` | Integer (segundos) | `localStorage` |

### Campos Formulario (Nuevo Paro)
| Campo | Tipo | Requerido | Fuente |
|-------|------|-----------|--------|
| `tipoParo` | `TipoParo` | Sí | `GET /api/v1/tipos-paro?centro={centro}&planificado={false|true}` |
| `codigoOperacion` | `CodigoOperacion` | Sí | Filtrado por `tipoParo` |
| `motivoLibre` | String(200) | No | Textarea |
| `lote` | String(40) | Sí | Input (persistido del último) |

### Llamadas API
| Acción | Endpoint | Método | Payload | Offline |
|--------|----------|--------|---------|---------|
| Cargar historial | `/api/v1/ordenes/{id}/paros` | GET | `turno, fecha` | Cache 30s |
| Guardar paro actual (Iniciar Producción) | `/api/v1/paros` | POST | `{ordenId, centroId, operarioId, turnoId, lote, horaInicio, horaFin, duracionSeg, tipoParoId, motivo, esPlanificado}` | **Queue** (`pendingParos`) |
| Generar nuevo paro (encadenar) | `/api/v1/paros` | POST | (mismo payload) | **Queue** |
| Razón sugerida (F2 toggle) | `/api/v1/paros/sugerir-razon` | POST | `{centroId, sensorData?}` | Network only |

### WebSocket Events (Tiempo Real)
| Evento | Payload | Acción UI |
|--------|---------|-----------|
| `paros:updated` | `{ordenId, centroId, paros[]}` | Refrescar `historialParos` |
| `paros:auto-detected` | `{centroId, tipoParoSugeridoId, confidence}` | Toast "¿Paro detectado? Confirmar" |

### Validaciones
- `lote` obligatorio antes de cualquier acción
- `tipoParo` + `codigoOperacion` obligatorios para "Generar Paro"
- "Iniciar Producción" cierra paro actual (set `horaFin = now`, `duracionSeg`)

### Offline
- **Crítico**: Cronómetro persiste en `localStorage` (survive reload)
- Historial: **cache first** + queue writes
- Queue flush: al recuperar conexión, POST batch `/api/v1/paros/batch`

### Permisos
- `Operario`, `Supervisor`, `Admin`

---

## 5. CONTROL DE PRODUCCIÓN (`/kiosk/:ordenId/produccion`)

### Estado Local
| Variable | Tipo | Persistencia |
|----------|------|--------------|
| `produccionActual` | `RegistroProduccion` (en curso) | `localStorage` + `IndexedDB` |
| `historialProduccion` | `RegistroProduccion[]` | `IndexedDB` |
| `cronometroActivo` | Boolean | `localStorage` |
| `horaInicioProduccion` | ISO String | `localStorage` |
| `objetivoHoraHora` | Integer (piezas/hora) | Calculado: `orden.cantEjecutar / horasTurno` |

### Campos Formulario
| Campo | Tipo | Requerido | Validación |
|-------|------|-----------|------------|
| `lote` | String(40) | Sí | Persistido del último |
| `piezasConformes` | Integer (≥0) | Sí | Stepper +/–; max `orden.cantPendiente` |
| `piezasNoConformes` | Integer (≥0) | Sí | Stepper +/–; si >0 → `motivoRechazo` requerido |
| `motivoRechazo` | `MotivoRechazo` | Si `piezasNoConformes > 0` | Dropdown |
| `tipoActividadSiguiente` | `TipoActividad` | Para "Parar Producción" | Dropdown |
| `codigoOperacionSiguiente` | `CodigoOperacion` | Para "Parar Producción" | Filtrado por `tipoActividadSiguiente` |

### KPIs en Header (Tiempo Real)
| KPI | Cálculo | Color |
|-----|---------|-------|
| **OEE** | `Disponibilidad × Desempeño × Calidad` | `#57A84B` / `#FF0000` / `#2BA8AD` |
| **Disponibilidad** | `1 - (tiempoParo / tiempoTurno)` | — |
| **Desempeño** | `piezasConformes / (tiempoProduccion * tasaIdeal)` | — |
| **Calidad** | `piezasConformes / (piezasConformes + piezasNoConformes)` | — |
| **Objetivo Hora-Hora** | `piezasConformesAcumuladas vs (horasTranscurridas * objetivoHoraHora)` | Barra verde/roja |

### Llamadas API
| Acción | Endpoint | Método | Payload | Offline |
|--------|----------|--------|---------|---------|
| Cargar historial | `/api/v1/ordenes/{id}/produccion` | GET | `turno, fecha` | Cache 30s |
| Guardar bloque (Parar Producción) | `/api/v1/produccion` | POST | `{ordenId, centroId, operarioId, turnoId, lote, horaInicio, horaFin, duracionSeg, piezasConformes, piezasNoConformes, motivoRechazoId, tipoActividadSiguienteId, codigoOperacionSiguienteId}` | **Queue** (`pendingProduccion`) |
| Objetivo hora-hora | `/api/v1/ordenes/{id}/objetivo-hora` | GET | — | Cache 1h |

### WebSocket Events
| Evento | Payload | Acción UI |
|--------|---------|-----------|
| `produccion:updated` | `{ordenId, centroId, produccion[]}` | Refrescar historial + KPIs |

### Transiciones
- "Parar Producción" → guarda bloque → navega a **Paros** (con `tipoActividadSiguiente`/`codigoOperacionSiguiente` preseleccionados) o **Operaciones** si cambia de orden

### Offline
- Cronómetro + formulario: **localStorage** persistente
- Queue flush: batch `/api/v1/produccion/batch`

### Permisos
- `Operario`, `Supervisor`, `Admin`

---

## 6. TRABAJO EN PROCESO (WIP) — **NUEVA PANTALLA** (`/admin/trabajo-en-proceso`)

### Propósito
Reemplaza **100% el proceso manual** de Excel → Generic Transfer → UnoE. Visibilidad total de sincronización con S/4HANA.

### Filtros (Sidebar)
| Filtro | Tipo | Default |
|--------|------|---------|
| Planta | Select | Usuario planta |
| Línea | Multi-select | Todas |
| Centro | Multi-select | Todas |
| Turno | Select | Turno actual |
| Fecha rango | Date range | Hoy |
| Estado Sync | Multi-select | `PENDING`, `ERROR` |
| Tipo entidad | Multi-select | `Produccion`, `Paros`, `Entregas`, `Rechazos` |

### Tabla Principal (AG Grid / TanStack Table)
| Columna | Campo | Ordenable | Filtrable |
|---------|-------|-----------|-----------|
| Fecha/Hora | `createdAt` | Sí | Sí |
| Planta | `planta.nombre` | Sí | Sí |
| Línea | `linea.nombre` | Sí | Sí |
| Centro | `centro.codigo` | Sí | Sí |
| Turno | `turno.codigo` | Sí | Sí |
| OP | `orden.opNumero` | Sí | Sí |
| Tipo | `entityType` (`Produccion`/`Paro`/`Entrega`/`Rechazo`) | Sí | Sí |
| Good | `piezasConformes` | Sí | No |
| Scrap | `piezasNoConformes` | Sí | No |
| Estado Sync | `s4_sync_status` (badge: 🟡 PENDING / 🟢 OK / 🔴 ERROR) | Sí | Sí |
| Último intento | `s4_sync_ts` | Sí | No |
| GUID S/4 | `s4_guid` | No | No |
| Error | `s4_error_msg` | No | Sí |

### Acciones (Toolbar + Row Actions)
| Acción | Endpoint | Descripción |
|--------|----------|-------------|
| Reintentar seleccionados | `POST /api/v1/sync/retry` | `{ids[]}` → reenvía a S/4HANA |
| Reintentar todos (filtrados) | `POST /api/v1/sync/retry-all` | `{filtros}` |
| Exportar CSV | Client-side | Descarga tabla filtrada |
| Ver detalle | Modal | Muestra payload completo + respuesta S/4HANA |

### Llamadas API
| Acción | Endpoint | Método |
|--------|----------|--------|
| Listar WIP | `/api/v1/wip` | GET (paginado, filtros) |
| Reintentar | `/api/v1/sync/retry` | POST |
| Reintentar todos | `/api/v1/sync/retry-all` | POST |
| Stats sync | `/api/v1/sync/stats` | GET (contadores por estado) |

### WebSocket
| Evento | Payload | Acción |
|--------|---------|--------|
| `sync:status-changed` | `{id, entityType, oldStatus, newStatus, s4_guid?}` | Actualizar fila en tiempo real |

### Permisos
- `Supervisor`, `Admin` (lectura)
- `Admin` (reintentar)

---

## 7. DASHBOARD ADMIN (`/admin/dashboard`)

### Componentes (Grid Layout)
| Componente | Datos | Tiempo Real | Librería |
|------------|-------|-------------|----------|
| Minutos Paro por Centro | `GET /api/v1/kpis/paros-por-centro?fecha={hoy}` | **WS `dashboard:kpis`** | Recharts (Bar horizontal) |
| Pareto Códigos Paro | `GET /api/v1/kpis/pareto-paros?fecha={hoy}` | **WS** | Recharts (Bar + Line 80%) |
| OEE por Centro/Turno | `GET /api/v1/kpis/oee?fecha={hoy}` | **WS** | Gauge + Sparkline 7d |
| Panel OPs en Proceso | `GET /api/v1/ordenes/en-proceso` | **WS `produccion:updated`, `paros:updated`** | Table + Semáforo |
| Andon Activos | `GET /api/v1/andon/activos` | **WS `andon:triggered`** | Lista + Toast + Sonido |

### Filtros Globales (Header)
- Planta, Línea, Turno, Rango fecha (hoy / ayer / 7d / 30d)

### Llamadas API
| Endpoint | Método | Parámetros | Cache |
|----------|--------|------------|-------|
| `/api/v1/kpis/paros-por-centro` | GET | `planta, linea, turno, fechaInicio, fechaFin` | 60s |
| `/api/v1/kpis/pareto-paros` | GET | `planta, linea, turno, fechaInicio, fechaFin` | 60s |
| `/api/v1/kpis/oee` | GET | `planta, linea, turno, fechaInicio, fechaFin` | 60s |
| `/api/v1/ordenes/en-proceso` | GET | `planta, linea, turno` | **WS only** (no cache) |
| `/api/v1/andon/activos` | GET | `planta, linea` | **WS only** |

### WebSocket Events
| Evento | Acción |
|--------|--------|
| `dashboard:kpis` | Actualizar todos los gráficos |
| `andon:triggered` | Nuevo toast + sonido + agregar a lista Andon |
| `paros:updated` / `produccion:updated` | Actualizar panel OPs en proceso |

### Exportar
- PNG (html2canvas), PDF (jsPDF), CSV (datos brutos)

### Permisos
- `Supervisor`, `Admin`

---

## 8. USUARIOS (`/admin/usuarios`)

### Tabla (CRUD Completo)
| Columna | Campo | Editable |
|---------|-------|----------|
| ID | `id` (cédula) | No |
| Nombre | `nombre` | Sí |
| Email | `email` | Sí |
| Teléfono | `telefono` | Sí |
| Rol | `rol` (Operario/Supervisor/Mantenimiento/Calidad/Admin) | Sí |
| Activo | `activo` (toggle) | Sí |
| Centros | `centros[]` (chips) | **Pestaña "Centros"** |

### Formulario (Modal)
| Campo | Tipo | Validación |
|-------|------|------------|
| `id` | String(20) | Único; regex cédula |
| `nombre` | String(100) | Requerido |
| `email` | String(120) | Email válido; único |
| `telefono` | String(30) | Opcional |
| `password` | String | Mín 8; **solo en creación / reset** |
| `rol` | Select | Requerido |
| `activo` | Boolean | Default true |

### Llamadas API
| Acción | Endpoint | Método |
|--------|----------|--------|
| Listar | `/api/v1/usuarios` | GET (paginado, search) |
| Crear | `/api/v1/usuarios` | POST |
| Actualizar | `/api/v1/usuarios/{id}` | PATCH |
| Eliminar | `/api/v1/usuarios/{id}` | DELETE (soft: `activo=false`) |
| Reset password | `/api/v1/usuarios/{id}/reset-password` | POST |
| Centros usuario | `/api/v1/usuarios/{id}/centros` | GET / POST / DELETE |

### Permisos
- `Admin` (CRUD completo)
- `Supervisor` (solo lectura + reset password propios centros)

---

## 9. USUARIOS × CENTRO (`/admin/usuarios-centros`)

### Vista Matriz (Tabla Pivot)
| Filas / Columnas | Usuarios (filas) × Centros (columnas) | Checkbox = asignado |
|------------------|----------------------------------------|---------------------|

### Acciones
| Acción | Endpoint | Método |
|--------|----------|--------|
| Cargar matriz | `/api/v1/usuarios-centros/matriz` | GET |
| Asignar | `/api/v1/usuarios-centros` | POST `{usuarioId, centroId}` |
| Desasignar | `/api/v1/usuarios-centros/{usuarioId}/{centroId}` | DELETE |
| Bulk assign | `/api/v1/usuarios-centros/bulk` | POST `{usuarioId, centroIds[]}` |
| Copiar de otro | `/api/v1/usuarios-centros/copy` | POST `{fromUsuarioId, toUsuarioId}` |

### Permisos
- `Admin`

---

## 10. ORDEN MANUAL (`/admin/orden-manual`)

### Formulario (21 Campos)
| Campo | Tipo | Requerido | Validación |
|-------|------|-----------|------------|
| `opPadre` | String(30) | Sí | Existe en S/4HANA (validación async) |
| `opNumero` | String(30) | Sí | Único en app |
| `operacion` | String(30) | Sí | Existe en `CodigoOperacion` |
| `fechaInicio` | Date | Sí | ≥ hoy |
| `fechaFin` | Date | Sí | ≥ `fechaInicio` |
| `cantEjecutar` | Decimal(15,3) | Sí | > 0 |
| `cantPendiente` | Decimal(15,3) | Sí | = `cantEjecutar` (default) |
| `cantCompleta` | Decimal(15,3) | No | Default 0 |
| `cantRetrabajo` | Decimal(15,3) | No | Default 0 |
| `cantRechazos` | Decimal(15,3) | No | Default 0 |
| `claseOP` | Select | Sí | Enum: `UNICA`, `COMPONENTE`, `RETRABAJO` |
| `centroTrabajo` | `CentroTrabajo` | Sí | Lookup autocomplete |
| `itemOP` | String(40) | Sí | Lookup `Material` (S/4HANA) |
| `itemOPRef` | String(40) | No | — |
| `itemOPResumen` | String(200) | No | — |
| `bodega` | String(20) | Sí | Lookup `Bodega` |
| `linea` | `Linea` | Sí | Lookup |
| `opReferencia1` | String(30) | No | — |
| `notas` | String(500) | No | — |

### Acciones
| Acción | Endpoint | Método |
|--------|----------|--------|
| Guardar | `/api/v1/ordenes/manual` | POST |
| Clonar | `/api/v1/ordenes/{id}/clonar` | POST |
| Guardar borrador | `/api/v1/ordenes/borrador` | POST |

### Permisos
- `Supervisor`, `Admin`

---

## 11. NAVEGACIÓN / SHELL (Layout Principal)

### Estructura
```
<AppShell>
  <Header>
    - Logo PROMAX (izq)
    - Usuario + Rol (centro)
    - Chip Offline/Online (der)
    - Icono Modo Guiado (toggle)
    - Icono Notificaciones (Andon count)
    - Menú Usuario (Perfil / Cerrar sesión)
  </Header>
  <Sidebar (colapsible en tablet)>
    - Centros de Trabajo (operario)
    - Trabajo en Proceso (supervisor/admin)
    - Dashboard (supervisor/admin)
    - Usuarios (admin)
    - Usuarios × Centro (admin)
    - Orden Manual (supervisor/admin)
    - Configuración (admin)
  </Sidebar>
  <Main> <Outlet /> </Main>
  <OfflineBanner /> (si offline)
  <ToastContainer />
  <AndonToast /> (persistente, sonido)
</AppShell>
```

### Offline Banner
- Chip fijo superior: `🟡 Sin conexión · 3 pendientes` + botón `Sincronizar ahora`
- Click → `POST /api/v1/sync/flush` (vacía todas las queues)

### Modo Guiado
- Toggle en header → `localStorage.guidedMode = true/false`
- Si `true`: tooltips paso a paso (driver.js) en cada pantalla

### WebSocket Connection
- Auto-conecta tras login
- Reconnect exponencial (1s, 2s, 4s, 8s, max 30s)
- Heartbeat 30s

### Permisos (Sidebar dinámico)
| Rol | Items Visibles |
|-----|----------------|
| `Operario` | Centros de Trabajo |
| `Supervisor` | + Trabajo en Proceso, Dashboard, Orden Manual |
| `Mantenimiento` | (Fase 3) |
| `Calidad` | (Fase 2) |
| `Admin` | Todos |

---

## Mejoras Transversales (Todas las Pantallas)

### Autenticación
- **Interna**: `Usuario.passwordHash` (bcrypt 12) + JWT RS256 (access 1h, refresh 24h/30d)
- **XSUAA**: Provisionado en BTP, **INACTIVO** (listo para SSO futuro)

### Paleta PROMAX (Tailwind `promax.*`)
```ts
primary: '#3860B2', header: '#616161', bg: '#EDEDED', card: '#FFFFFF',
green: '#57A84B', red: '#FF0000', teal: '#2BA8AD', cyan: '#48BBDD',
navy: '#0D2535', navyLight: '#0E202E', blue2: '#005E92',
text: '#1C1C1C', textMuted: '#62686C', border: '#C8C4C0', focus: '#3860B2'
```

### Responsive
- Breakpoint tablet: `768px` (sidebar colapsa a rail)
- Touch targets: `min-h-[48px] min-w-[48px]`
- Fuentes: `text-base` (16px) móvil, `text-lg` (18px) desktop

### Offline-First (IndexedDB + Dexie.js)
| Queue | Entidad | Flush Trigger |
|-------|---------|---------------|
| `pendingParos` | `RegistroParo` | Online + cada 30s |
| `pendingProduccion` | `RegistroProduccion` | Online + cada 30s |
| `pendingIniciarOrden` | `OrdenProduccion` | Online |
| `pendingIniciarProduccion` | — | Online |
| `pendingSync` | Genérico (WIP retry) | Manual + job nocturno |

### WebSocket (Socket.io)
- Namespace `/realtime`
- Eventos: `paros:updated`, `produccion:updated`, `andon:triggered`, `dashboard:kpis`, `sync:status-changed`
- Auth: JWT en handshake `auth: {token}`

### Validación Client-Side
- React Hook Form + Zod schemas (compartidos frontend/backend via `shared/schemas`)

### Accesibilidad (WCAG 2.1 AA)
- Contraste ≥ 4.5:1 (verificado en paleta)
- Focus visible: `ring-2 ring-promax-focus`
- ARIA labels en todos los inputs, botones, iconos
- Navegación teclado completa (Tab, Enter, Escape, Flechas)

### i18n (ES/EN)
- `i18next` + `locales/es.json`, `locales/en.json`
- Detección: `navigator.language` → fallback `es`

### Auditoría (Backend)
- `AuditLog` entidad CDS: `usuarioId`, `accion`, `entidad`, `entidadId`, `timestamp`, `diff` (JSON), `ip`
- Middleware automático en mutaciones (POST/PATCH/DELETE)

---

## Próximos Entregables (Ya en Progreso)

1. `db/schema.cds` — Modelo CDS definitivo (entidades + vistas + anotaciones)
2. `srv/openapi.yaml` — Spec OpenAPI 3.1 completa (paths, schemas, security)
3. `shared/schemas/` — Zod schemas (frontend + backend types)
4. Storybook mockups: Pantallas 2, 4, 6, 8 (las marcadas con 🔄 en approval)