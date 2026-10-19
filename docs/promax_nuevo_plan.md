# PROMAX NUEVO — Plan Funcional y Técnico Detallado

> **Versión**: 1.0 — 18-oct-2026  
> **Para**: Equipo de desarrollo (pm, architect, backend, frontend, qa, devops)  
> **Fuentes**: Análisis funcional PROMAX actual (3 PDFs), investigación MES/CMMS open source + comercial (40 fuentes), paleta UI extraída de capturas, APIs oficiales S/4HANA Cloud, CAP Remote Services.  
> Todas las afirmaciones externas llevan cita numerada; ver lista **Sources** al final.

---

## 1. Contexto y Objetivo

**PROMAX actual**: App Power Apps + SharePoint + Siesa UnoE (cargues manuales vía Generic Transfer + Excel → .txt). 12 módulos funcionales, arquitectura low-code, datos en listas SharePoint, sin tiempo real real, sin calidad estructurada, mantenimiento reactivo.

**PROMAX nuevo**: MES nativo cloud (React Vite/Next + CAP Node.js + HANA Cloud) desplegado en **Cloud Foundry (SAP BTP)**, conectado **directo y en tiempo real** a **SAP S/4HANA Cloud Public Edition (estándar)** vía **OData V2/V4 + Destinations**, conservando la **identidad visual (colores, flujos, terminología)** del PROMAX original, incorporando las mejores prácticas de la investigación (Tulip, L2L, MachineMetrics, Sepasoft, MaintainX, SafetyCulture, OpenMES, ERPNext/Frappe apps).

**Alcance MVP (fases 1–3 ≈ 16–20 sem):**
- F1 (6–8 sem): Piso digital — órdenes, kiosco tablet, paros, OEE, Andon.
- F2 (4–6 sem): Calidad — checklists condicionales, inspección en línea, NC/CAPA.
- F3 (4–6 sem): Mantenimiento — WO, PM calendario/metro, activos+QR, MTBF/MTTR.
- F4 (continuo): Trazabilidad lote/serial, conectividad OPC UA/MQTT, SPC, IA.

---

## 2. Identidad Visual — Paleta Oficial PROMAX (extraída de capturas)

| Uso | Hex | Contexto |
|-----|-----|----------|
| **Azul primario (header, botones primarios, acentos)** | `#3860B2` | Header apps operativas, botón "Iniciar", gráficos admin |
| **Gris header / texto principal** | `#616161` | Barras superiores, textos, iconos |
| **Fondo general / tarjetas** | `#EDEDED` / `#E6E6E6` | Fondos de pantalla, listas |
| **Verde acción / producción / OK** | `#57A84B` / `#6BA540` | Botón "Iniciar Producción", semáforo verde |
| **Rojo paro / alerta / scrap** | `#FF0000` | Semáforo rojo, botón "Parar Producción", rechazos |
| **Teal / cian acentos gráficos** | `#2BA8AD` / `#48BBDD` | Gráficos admin, indicadores secundarios |
| **Navy portada / login** | `#0D2535` / `#0E202E` | Pantalla de bienvenida, login |
| **Azul secundario (módulo usuarios)** | `#005E92` | Header módulo usuarios |
| **Texto sobre fondo oscuro** | `#FFFFFF` | Login, portada |
| **Texto sobre fondo claro** | `#1C1C1C` / `#353535` | Formularios, tablas |

**Tipografía**: Sans-serif del sistema (Inter / Roboto / system-ui), tamaños base 14–16 px, headings 20–24 px.  
**Estilo**: Tarjetas con sombra sutil, bordes redondeados 8 px, iconografía outline (Material / Lucide), semáforos circulares 12 px, inputs con borde `#C8C4C0`, focus ring `#3860B2`.  
**Responsive**: Mobile-first tablet (768–1024 px) — el kiosco de operario es la vista principal.

---

## 3. Arquitectura Técnica

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SAP BTP Cloud Foundry                        │
│  ┌──────────────────┐     ┌────────────────────────────────────┐  │
│  │  Frontend (React │     │       Backend CAP (Node.js)        │  │
│  │   Vite/Next.js)  │◄───►│  • CDS model (MES domain)          │  │
│  │  • PWA/offline   │     │  • HANA Cloud (SQL)                │  │
│  │  • Tablet kiosk  │     │  • XSUAA + roles                   │  │
│  │  • i18n ES/EN    │     │  • Remote Services → S/4HANA       │  │
│  └────────┬─────────┘     └───────────────┬────────────────────┘  │
│           │                               │                       │
│           │ HTTPS / OData V4              │ Destinations (BTP)    │
│           ▼                               ▼                       │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │              SAP S/4HANA Cloud Public Edition              │  │
│  │  API_PRODUCTION_ORDER_2      API_MAINTNOTIFICATION         │  │
│  │  API_PRODUCTION_ORDER_CONF   API_MAINTORDER                │  │
│  │  API_BATCH_MASTER            API_QUALITY_NOTIFICATION      │  │
│  │  API_INSPECTION_LOT          API_MATERIAL_STOCK            │  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

**Decisiones clave**:
- **Frontend**: **React + Vite + TypeScript + TailwindCSS** (PWA, offline-first con IndexedDB + sync engine). Next.js solo si se requiere SSR/SEO — no es el caso (app privada).
- **Backend**: **CAP Node.js (cds)** — modelo CDS en `db/schema.cds`, servicios en `srv/`, Remote Services configurados en `package.json` / `.cdsrc.json` [46][47].
- **Base de datos**: **HANA Cloud** (instancia `mi-hana-db`, free tier, schema `PROMAX_MES`) — tablas CDS persistidas, índices GIST para búsquedas geo/texto si procede.
- **Auth**: **XSUAA** (ya configurado en tu cuenta BTP trial `2c3ffa98trial`) — roles: `Operario`, `Supervisor`, `Mantenimiento`, `Calidad`, `Admin`.
- **Destinations BTP**: Una por API S/4HANA (ej. `s4-production-order`, `s4-maintenance`, `s4-quality`) con `Authentication=OAuth2ClientCredentials` y `tokenServiceURL` del Communication System en S/4HANA.
- **Tiempo real**: WebSocket (Socket.io) para Andon / dashboard admin; polling 5s fallback.

---

## 4. Modelo de Datos CDS (esquema `PROMAX_MES`)

```cds
namespace promax.mes;

using { managed, cuid, temporal } from '@sap/cds/common';

// ── Maestros ──────────────────────────────────────────────────────
entity Planta : managed { key codigo : String(10); nombre : String(80); pais : String(3); zonaHoraria : String(40); }
entity Linea : managed { key codigo : String(20); nombre : String(80); planta : Association to Planta; }
entity CentroTrabajo : managed {
  key codigo : String(30); nombre : String(100); linea : Association to Linea;
  grupo : String(20); divisionTiempo : String(20); bodegaCT : String(20);
  centroAnterior : Association to CentroTrabajo; // para flujo
  activo : Boolean default true;
}
entity Turno : managed {
  key codigo : String(10); nombre : String(40); planta : Association to Planta;
  horaInicio : Time; horaFin : Time; diasAplicable : String(50); // L-V, S, D/F
}
entity Calendario : managed { key fecha : Date; turno : Association to Turno; esLaborable : Boolean; }
entity Usuario : managed {
  key id : String(20); // cédula
  nombre : String(100); email : String(120); telefono : String(30);
  passwordHash : String(255); rol : String(20); // Operario, Supervisor, Mantenimiento, Calidad, Admin
  activo : Boolean default true;
}
entity UsuarioCentro : managed {
  key usuario : Association to Usuario; key centro : Association to CentroTrabajo;
  habilitado : Boolean default true;
}
entity Habilidad : managed { key codigo : String(30); nombre : String(80); }
entity UsuarioHabilidad : managed { key usuario : Association to Usuario; key habilidad : Association to Habilidad; nivel : Integer; vencimiento : Date; }

// ── Catálogos de paro / rechazo / actividad ──────────────────────
entity TipoParo : managed { key codigo : String(20); descripcion : String(100); tipo : String(20); // Planificado, NoPlanificado
  tipohora : String(20); // para UnoE
}
entity MotivoRechazo : managed { key id : String(20); descripcion : String(120); }
entity TipoActividad : managed { key codigo : String(20); descripcion : String(100); categoria : String(30); }
entity CodigoOperacion : managed {
  key codigo : String(30); descripcion : String(120); tipoActividad : Association to TipoActividad;
}

// ── Órdenes y operaciones ────────────────────────────────────────
entity OrdenProduccion : managed {
  key opPadre : String(30); key opNumero : String(30); key operacion : String(30);
  itemOP : String(40); itemOPRef : String(40); itemOPResumen : String(200);
  estado : String(20); // Aprobada, EnProceso, Completada, Cancelada
  fechaInicio : DateTime; fechaFin : DateTime; fechaDocumento : DateTime;
  cantEjecutar : Decimal(15,3); cantPendiente : Decimal(15,3); cantCompleta : Decimal(15,3);
  cantRetrabajo : Decimal(15,3); cantRechazos : Decimal(15,3);
  centroTrabajo : Association to CentroTrabajo; bodega : String(20); linea : Association to Linea;
  claseOP : String(20); opReferencial : String(30); notas : String(500);
  pesoEnKls : Decimal(15,3); cantidadEjecutarKls : Decimal(15,3);
  // sincronización S/4HANA
  s4_sync_ts : DateTime; s4_sync_status : String(20); s4_guid : String(36);
}
entity OperacionOrden : managed {
  key orden : Association to OrdenProduccion; key numeroOperacion : Integer;
  codigoOperacion : Association to CodigoOperacion; centroTrabajo : Association to CentroTrabajo;
  cantPlaneada : Decimal(15,3); cantCompleta : Decimal(15,3); estado : String(20);
}

// ── Ejecución en piso ────────────────────────────────────────────
entity RegistroProduccion : managed {
  key id : UUID;
  orden : Association to OrdenProduccion; operacion : Association to OperacionOrden;
  centroTrabajo : Association to CentroTrabajo; operario : Association to Usuario;
  turno : Association to Turno; fecha : DateTime;
  horaInicio : DateTime; horaFin : DateTime; tiempoUsado : Integer; // segundos
  piezasConformes : Decimal(15,3); piezasNoConformes : Decimal(15,3);
  lote : String(40); paquete : String(40); requerimiento : String(40);
  tipoHora : String(20); // Produccion, Paro, PuestaPunto, Ajuste
  // trazabilidad
  s4_te_guid : String(36); s4_sync_ts : DateTime;
}
entity RegistroParo : managed {
  key id : UUID;
  registroProduccion : Association to RegistroProduccion; // encadenado
  centroTrabajo : Association to CentroTrabajo; operario : Association to Usuario;
  turno : Association to Turno; fecha : DateTime;
  horaInicio : DateTime; horaFin : DateTime; duracionSeg : Integer;
  tipoParo : Association to TipoParo; motivo : String(200); // nota libre
  esPlanificado : Boolean; // derivado de tipoParo.tipo
  s4_notif_guid : String(36); // si genera notificación mantenimiento
}

// ── Calidad ──────────────────────────────────────────────────────
entity PlantillaChecklist : managed {
  key id : UUID; nombre : String(100); version : Integer; activa : Boolean;
  aplicaACentro : Association to CentroTrabajo; aplicaAItem : String(40);
  jsonLogic : String(5000); // lógica condicional (jsonlogic)
}
entity Inspeccion : managed {
  key id : UUID;
  orden : Association to OrdenProduccion; operacion : Association to OperacionOrden;
  plantilla : Association to PlantillaChecklist; inspector : Association to Usuario;
  centroTrabajo : Association to CentroTrabajo; fecha : DateTime;
  estado : String(20); // EnProceso, Aprobada, Rechazada, Hold
  resultadosJson : String(10000); // respuestas + fotos (base64/URL)
  holdHasta : DateTime; // si queda en hold
}
entity NoConformidad : managed {
  key id : UUID; inspeccion : Association to Inspeccion; lote : String(40);
  descripcion : String(500); motivoRechazo : Association to MotivoRechazo;
  severidad : String(20); // Leve, Mayor, Crítica
  responsable : Association to Usuario; fechaApertura : DateTime; fechaCierre : DateTime;
  estado : String(20); // Abierta, EnAnalisis, Cerrada
  accionCorrectiva : String(2000); accionPreventiva : String(2000);
  eficaciaVerificada : Boolean; fechaVerificacion : DateTime;
}

// ── Mantenimiento ────────────────────────────────────────────────
entity Activo : managed {
  key codigo : String(40); nombre : String(120); centroTrabajo : Association to CentroTrabajo;
  jerarquiaPadre : Association to Activo; tipo : String(30); // Maquina, Herramienta, Instalacion
  numeroSerie : String(60); fabricante : String(80); modelo : String(80);
  fechaInstalacion : DateTime; ubicacionFisica : String(100); qrCode : String(200);
  medidorHoras : Decimal(15,2); medidorCiclos : Decimal(15,2); ultimaLectura : DateTime;
  critico : Boolean; // para criticidad
}
entity PlanMantenimiento : managed {
  key id : UUID; activo : Association to Activo; nombre : String(100);
  tipo : String(20); // Calendario, MedidorHoras, MedidorCiclos, Condicion
  frecuenciaDias : Integer; frecuenciaHoras : Decimal(15,2); frecuenciaCiclos : Decimal(15,2);
  toleranciaDias : Integer; proximaEjecucion : DateTime; activoFlag : Boolean;
  checklist : Association to PlantillaChecklist; // reutiliza plantillas
  responsableRol : String(20);
}
entity OrdenTrabajoMant : managed {
  key id : UUID; plan : Association to PlanMantenimiento; activo : Association to Activo;
  tipo : String(20); // Preventiva, Correctiva, Predictiva, Mejora
  prioridad : String(10); // Alta, Media, Baja
  solicitante : Association to Usuario; asignadoA : Association to Usuario;
  fechaCreacion : DateTime; fechaProgramada : DateTime; fechaInicio : DateTime; fechaFin : DateTime;
  estado : String(20); // Abierta, Asignada, EnProceso, Pausada, Completada, Cancelada
  descripcion : String(1000); causaRaiz : String(1000); accionTomada : String(2000);
  tiempoRealHoras : Decimal(8,2); costoMateriales : Decimal(15,2); costoManoObra : Decimal(15,2);
  // chat/fotos embebidos en adjuntos
  s4_maint_order_guid : String(36); s4_sync_ts : DateTime;
}
entity Repuesto : managed {
  key codigo : String(40); nombre : String(120); unidad : String(10); stockMin : Decimal(15,3); stockActual : Decimal(15,3);
  ubicacionBodega : String(20); costoUnitario : Decimal(15,2); critico : Boolean;
}
entity MovimientoRepuesto : managed {
  key id : UUID; repuesto : Association to Repuesto; ordenTrabajo : Association to OrdenTrabajoMant;
  tipo : String(10); // Salida, Entrada, Ajuste, Transferencia
  cantidad : Decimal(15,3); fecha : DateTime; responsable : Association to Usuario; lote : String(40);
}

// ── KPIs / Analítica (vistas materializadas) ─────────────────────
view OEECalculado as select from RegistroProduccion join CentroTrabajo join Turno join OrdenProduccion
{ centroTrabajo.codigo as centro, fecha, turno.codigo as turno,
  sum(case when tipoHora='Produccion' then tiempoUsado else 0 end) as t_produccion,
  sum(case when tipoHora='Paro' then tiempoUsado else 0 end) as t_paro,
  sum(case when tipoHora in ('PuestaPunto','Ajuste') then tiempoUsado else 0 end) as t_setup,
  sum(piezasConformes) as good, sum(piezasNoConformes) as scrap,
  (sum(piezasConformes) / nullif(sum(piezasConformes)+sum(piezasNoConformes),0)) * 100 as calidad_pct
} group by centroTrabajo.codigo, fecha, turno.codigo;
```

---

## 5. Servicios CAP (Remote Services → S/4HANA Cloud)

Configuración en `package.json` (Node.js) o `.cdsrc.json`:

```json
{
  "cds": {
    "requires": {
      "db": { "kind": "hana" },
      "auth": { "kind": "xsuaa" },
      "s4-production-order": { "kind": "odata-v2", "model": "srv/external/API_PRODUCTION_ORDER_2", "csrf": true, "credentials": { "destination": "s4-production-order", "requestTimeout": 120000 } },
      "s4-production-conf": { "kind": "odata-v2", "model": "srv/external/API_PRODUCTION_ORDER_CONFIRMATION_2", "csrf": true, "credentials": { "destination": "s4-production-order", "requestTimeout": 120000 } },
      "s4-maintenance-notif": { "kind": "odata-v2", "model": "srv/external/API_MAINTNOTIFICATION", "csrf": true, "credentials": { "destination": "s4-maintenance", "requestTimeout": 120000 } },
      "s4-maintenance-order": { "kind": "odata-v2", "model": "srv/external/API_MAINTORDER", "csrf": true, "credentials": { "destination": "s4-maintenance", "requestTimeout": 120000 } },
      "s4-quality-notif": { "kind": "odata-v2", "model": "srv/external/API_QUALITY_NOTIFICATION", "csrf": true, "credentials": { "destination": "s4-quality", "requestTimeout": 120000 } },
      "s4-inspection-lot": { "kind": "odata-v2", "model": "srv/external/API_INSPECTION_LOT", "csrf": true, "credentials": { "destination": "s4-quality", "requestTimeout": 120000 } },
      "s4-material-stock": { "kind": "odata-v2", "model": "srv/external/API_MATERIAL_STOCK", "credentials": { "destination": "s4-material", "requestTimeout": 60000 } }
    }
  }
}
```

**Communication Scenarios S/4HANA requeridos** (configurar en S/4HANA Cloud → Communication Management):
- `SAP_COM_0051` — Production Order Integration
- `SAP_COM_0052` — Production Order Confirmation
- `SAP_COM_0397` — Maintenance Processing Integration
- `SAP_COM_0398` — Plant Maintenance Execution Integration
- `SAP_COM_0179` — Quality Management Integration
- `SAP_COM_0259` — Inspection Lot Integration
- `SAP_COM_0315` — Material Stock Integration [41][42][44][45]

**Patrón de consumo en CAP** (ej. crear confirmación de producción):

```js
// srv/lib/production.js
const { ProductionOrderConfirmation } = cds.entities('s4-production-conf');
async function confirmarProduccion(orden, operacion, good, scrap, lote, usuario) {
  const s4 = await cds.connect.to('s4-production-conf');
  const payload = {
    ProductionOrder: orden.opNumero,
    Operation: operacion.numeroOperacion,
    ConfirmationType: 'F', // Final
    YieldQuantity: good,
    ScrapQuantity: scrap,
    UoM: 'EA',
    PostingDate: new Date().toISOString().split('T')[0],
    GoodsMovement: [{ Material: orden.itemOP, Plant: '1000', StorageLocation: orden.bodega,
                      Batch: lote, MovementType: '101', Quantity: good }],
    // ... campos obligatorios según EDMX
  };
  const res = await s4.run(INSERT.into(ProductionOrderConfirmation).entries(payload));
  return res; // contiene GUID S/4HANA para trazabilidad
}
```

**Manejo de errores / idempotencia**: cada envío a S/4HANA guarda `s4_sync_ts`, `s4_sync_status` (`PENDING`, `OK`, `ERROR`), `s4_guid` en la entidad local. Job programado (cds-cron) reintenta `ERROR` con backoff exponencial.

---

## 6. Frontend — React Vite + TypeScript + TailwindCSS

### 6.1 Estructura del proyecto

```
promax-frontend/
├─ public/
├─ src/
│  ├─ app/
│  │  ├─ routes.tsx            # React Router v6, lazy load por rol
│  │  ├─ providers.tsx         # Auth, Theme, QueryClient, WebSocket, i18n
│  ├─ features/
│  │  ├─ auth/                 # Login, logout, token refresh
│  │  ├─ kiosk/                # Vista operario (centros, operaciones, paros, producción)
│  │  ├─ admin/                # Dashboard tiempo real, gráficos OEE, Andon
│  │  ├─ quality/              # Checklists, inspecciones, NC/CAPA
│  │  ├─ maintenance/          # Activos, PM, WO, repuestos
│  │  ├─ master-data/          # Catálogos, usuarios, centros, turnos
│  │  └─ integration/          # Sync status, colas S/4HANA
│  ├─ shared/
│  │  ├─ ui/                   # Button, Card, Table, Select, Modal, Toast, Semaphore
│  │  ├─ hooks/                # useAuth, useOfflineQueue, useWebSocket, usePermissions
│  │  ├─ api/                  # Axios instance + interceptors (OData V4 CAP)
│  │  ├─ constants/            # colors.ts (paleta oficial), enums, routes
│  │  └─ utils/                # date, format, offline-storage, qr-scanner
│  ├─ styles/
│  │  ├─ tailwind.css          # @theme con paleta PROMAX
│  │  └─ global.css
│  └─ main.tsx
├─ index.html
├─ vite.config.ts
├─ tsconfig.json
└─ package.json
```

### 6.2 Tailwind theme (`tailwind.config.ts`)

```ts
import type { Config } from 'tailwindcss';
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        promax: {
          primary: '#3860B2',
          'primary-hover': '#2D4D8F',
          header: '#616161',
          bg: '#EDEDED',
          card: '#FFFFFF',
          green: '#57A84B',
          'green-hover': '#4A923E',
          red: '#FF0000',
          'red-hover': '#CC0000',
          teal: '#2BA8AD',
          cyan: '#48BBDD',
          navy: '#0D2535',
          'navy-light': '#0E202E',
          blue2: '#005E92',
          text: '#1C1C1C',
          'text-muted': '#62686C',
          border: '#C8C4C0',
          focus: '#3860B2',
        }
      },
      fontFamily: { sans: ['Inter', 'system-ui', 'sans-serif'] },
      borderRadius: { DEFAULT: '8px', lg: '12px' },
      boxShadow: { card: '0 2px 8px rgba(0,0,0,0.08)', elevated: '0 4px 16px rgba(0,0,0,0.12)' },
    },
  },
  plugins: [],
} satisfies Config;
```

### 6.3 Flujo de navegación (mirror PROMAX)

| Pantalla PROMAX original | Ruta nueva | Componente clave |
|--------------------------|------------|------------------|
| Login | `/login` | `LoginForm` (cédula + password + ojo) |
| Centros de Trabajo | `/kiosk` | `CentroSelector` (turno + centro + búsqueda OP + barcode + multi-selección + nesteo) |
| Operaciones | `/kiosk/:ordenId/operaciones` | `OperacionesSetup` (operarios, tipo actividad, códigos, galería ops) |
| Control Paros | `/kiosk/:ordenId/paros` | `ParosKiosk` (cronómetro auto, lote, galería historial, "Iniciar Producción", "Nuevo Paro"/"Generar Paro") |
| Control Producción | `/kiosk/:ordenId/produccion` | `ProduccionKiosk` (cronómetro, lote, good/scrap, "Parar Producción", transición actividad) |
| Cargue Masivo TEP/Entregas/Rechazos | `/admin/cargue-masivo` | `CargueMasivo` (plantillas Excel → OData batch → S/4HANA) — **automatiza el proceso manual actual** |
| Dashboard Admin | `/admin/dashboard` | `AdminDashboard` (gráficos min/parada, Pareto códigos paro, panel OPs en proceso, semáforos) |
| Usuarios | `/admin/usuarios` | `UsuariosCrud` (buscar, listado, formulario, editar/eliminar) |
| Usuarios × Centro | `/admin/usuarios-centros` | `UsuarioCentroCrud` |
| Orden Manual | `/admin/orden-manual` | `OrdenManualForm` (todos los campos del PDF §12) |

### 6.4 Offline-first (tablet en planta sin WiFi estable)

- **IndexedDB** (Dexie.js) para colas: `pendingProduccion`, `pendingParos`, `pendingInspecciones`, `pendingWO`.
- **Service Worker** (Workbox) precachea shell + assets; `backgroundSync` para flush al recuperar conexión.
- **Indicador visual**: chip "Sin conexión · N pendientes" en header; botón "Sincronizar ahora".

### 6.5 WebSocket (Tiempo Real)

- Backend expone `ws://.../realtime` (Socket.io).
- Eventos: `paros:updated`, `produccion:updated`, `andon:triggered`, `dashboard:kpis`.
- Frontend: `useWebSocket` hook → actualiza React Query cache → UI reactiva sin polling.

---

## 7. Módulos Funcionales — Detalle por Pantalla (mejoras incluidas)

### 7.1 Login (`/login`)
- **Igual que PROMAX**: cédula + password + toggle ojo + botón "Ingresar".
- **Mejoras**: SSO opcional vía XSUAA/OIDC; "Olvidé contraseña" con email; bloqueo tras 5 intentos; MFA futuro.

### 7.2 Centros de Trabajo (`/kiosk`)
- **Selector turno** (lista dinámica desde `Calendario` + `Turno`).
- **Selector centro** (filtrado por `UsuarioCentro` del usuario logueado).
- **Búsqueda OP**: texto (OP padre/hija) + **barcode scanner** (Web Barcode API / QuaggaJS).
- **Modo múltiple**: checkboxes + contador "X de Y seleccionadas" + botón "Iniciar" habilitado solo si coincide lote programado.
- **Modo nesteo** (solo centros corte caliente): selector nesteo → auto-selecciona todas las OPs del nesteo.
- **Mejoras vs PROMAX**: vista kanban de OPs (ToDo/EnProceso/Done); drag-to-reorder; filtro por estado, referencia, prioridad; indicador de capacidad finita (rojo si sobrecargado).

### 7.3 Operaciones (`/kiosk/:ordenId/operaciones`)
- **Parametrización obligatoria** (asterisco rojo):
  - Cantidad operarios (1–N) + **escaneo cédula ayudantes** (valida contra `Usuario` + `UsuarioCentro`).
  - Tipo actividad inicial (dropdown `TipoActividad`).
  - Código operación (filtrado por tipo actividad → `CodigoOperacion`).
- **Cabecera fija**: usuario + icono info paros (modal con catálogo `TipoParo` agrupado por categoría).
- **Galería operaciones**: lista `OperacionOrden` con estado visual (pendiente/en proceso/completa).
- **Botón "Iniciar"** → valida campos * → navega a Paros (si tipo actividad = Paro) o Producción (si = Producción).

### 7.4 Control de Paros (`/kiosk/:ordenId/paros`)
- **Cronómetro automático** (inicia al entrar, formato HH:MM:SS, persiste en localStorage + IndexedDB).
- **Campo lote/paquete** obligatorio.
- **Galería historial** (lista `RegistroParo` del turno/centro) + botón refresh (re-sync).
- **Acciones**:
  - **Iniciar Producción** → cierra paro actual (`horaFin = now`, `duracionSeg`), crea `RegistroProduccion` tipo `Produccion`, navega a Producción.
  - **Nuevo Paro** → habilita dropdowns `TipoParo` (planificado/no planificado) + `CodigoOperacion` filtrado → **Generar Paro** → guarda registro anterior, inicia nuevo cronómetro.
- **Mejoras**: **Detección automática de paro** si hay señal OPC UA (F4) — muestra toast "¿Paro detectado? Confirmar"; razón de paro sugerida por regla (Sepasoft-style) [26]; notas de voz (Web Speech API) para operario con guantes.

### 7.5 Control de Producción (`/kiosk/:ordenId/produccion`)
- **Cronómetro producción** (inicia al entrar).
- **Campos**: lote/paquete, **ensambles terminados** (numérico, stepper +/–), **scrap** (numérico), **motivo rechazo** (dropdown `MotivoRechazo` si scrap > 0).
- **Galería bloques** (historial `RegistroProduccion` del turno).
- **Parar Producción** → guarda registro, reinicia cronómetro con nuevo tipo actividad/código → vuelve a Paros o cambia actividad.
- **Mejoras**: **Objetivo hora-hora** (desde `OrdenProduccion.cantEjecutar` / horas turno) → barra de progreso verde/rojo; **OEE en vivo** (disponibilidad = 1 - paro/turno; desempeño = real/ideal; calidad = good/total) — chip semáforo en header.

### 7.6 Cargue Masivo (automatizado) — `/admin/cargue-masivo`
**Reemplaza el proceso 100% manual actual (Excel → limpiar → Generic Transfer → .txt → UnoE Importar)**.
- **Plantillas** generadas desde CDS (`Caida_de_datos`, `Entregas_PAPP`, `Entregas_rechazados`) con columnas exactas S/4HANA.
- **Validación client-side**: requeridos, tipos, rangos, duplicados `POWERAPPSID`.
- **Envío**: batch OData V4 a CAP → CAP mapea a `API_PRODUCTION_ORDER_CONFIRMATION_2` + `API_MATERIAL_DOCUMENT` + `API_QUALITY_NOTIFICATION` → **una sola llamada** desde frontend.
- **Resultado**: tabla de "Éxito / Error por fila" con `s4_guid` o mensaje error; reintento automático de errores.

### 7.7 Dashboard Admin (`/admin/dashboard`)
- **Gráficos** (Recharts / Chart.js):
  - Minutos de paro por centro (barra horizontal, eje Y centros, X minutos) — **color `#3860B2`**.
  - Pareto códigos de paro (barra + línea acumulada 80%) — **rojo `#FF0000` para top 3**.
  - OEE por centro/turno (gauge + trend 7 días).
- **Panel OPs en proceso** (tabla tiempo real vía WS): Centro, Estado (semáforo verde/rojo), OP, Requerimiento, Operario, Hora Inicio, Duración actual.
- **Filtros**: planta, línea, turno, rango fecha.
- **Exportar**: PNG/PDF (html2canvas + jsPDF) / CSV.
- **Mejoras vs PROMAX**: drill-down al centro → detalle de paros del día; alerta Andon en tiempo real (toast + sonido + persistencia en `AndonEvent`).

### 7.8 Calidad — Checklists e Inspecciones (`/quality`)
- **PlantillaChecklist** (editor JSON Logic visual tipo Tulip [29]): preguntas con tipo (texto, número, select, foto, firma, GPS), lógica condicional (`showIf: "pregunta1 == 'Sí'"`), obligatorias, rango válido.
- **Inspección en kiosco**: operario/calidad abre checklist asignada a la OP/operación → responde → fotos (cámara) → firma → **Hold/Release** automático según reglas.
- **No Conformidad**: si inspección `Rechazada` o `Hold` → crea `NoConformidad` con responsable, severidad, fechas, CAPA → workflow de aprobación (Supervisor → Calidad → Cierre).
- **Trazabilidad**: `Inspeccion` ligada a `RegistroProduccion` + `Lote` → genealogy forward/backward.

### 7.9 Mantenimiento (`/maintenance`)
- **Activos**: árbol jerárquico (centro → máquina → componente) + QR code en ficha.
- **Plan PM**: calendario / medidor horas / medidor ciclos / condición (umbral sensor) → genera `OrdenTrabajoMant` automática (job nocturno).
- **WO Mantenimiento**: kanban (Abierta → Asignada → EnProceso → Completada) + chat interno (comentarios + fotos) + repuestos (picker con stock actual) + tiempo real + costo.
- **KPIs**: MTBF/MTTR por activo, % planificado vs reactivo, cumplimiento PM, backlog.
- **Integración S/4HANA**: `API_MAINTNOTIFICATION` (crear notificación desde paro no planificado) → `API_MAINTORDER` (crear orden desde plan PM) [44][45].

### 7.10 Maestros y Administración (`/admin/*`)
- CRUD estándar con búsqueda, paginación, ordenación, exportar CSV.
- **Usuarios**: roles + asignación centros + habilidades + certificación (vencimientos).
- **Catálogos**: `TipoParo`, `MotivoRechazo`, `TipoActividad`, `CodigoOperacion`, `Turno`, `Calendario` — edición inline + importar Excel.

---

## 8. Integración S/4HANA Cloud — Flujos Críticos

| Evento en PROMAX Nuevo | API S/4HANA | Dirección | Descripción |
|------------------------|-------------|-----------|-------------|
| Carga inicial de OPs aprobadas | `API_PRODUCTION_ORDER_2` (GET) | S/4 → PROMAX | Job cada 15 min / webhook `ProductionOrderChanged` → sincroniza `OrdenProduccion` + `OperacionOrden` |
| Confirmación producción (good/scrap) | `API_PRODUCTION_ORDER_CONFIRMATION_2` (POST) | PROMAX → S/4 | Al guardar `RegistroProduccion` (batch cada 30s o al "Parar Producción") |
| Consumo material (lote) | `API_MATERIAL_DOCUMENT` (POST) | PROMAX → S/4 | Movimiento 261/101 según BOM |
| Paro no planificado → notificación mantenimiento | `API_MAINTNOTIFICATION` (POST) | PROMAX → S/4 | Al crear `RegistroParo` con `esPlanificado=false` y `tipoParo` crítico |
| Plan PM → Orden mantenimiento | `API_MAINTORDER` (POST) | PROMAX → S/4 | Job nocturno al vencer `PlanMantenimiento.proximaEjecucion` |
| Inspección → lote de inspección / notificación calidad | `API_INSPECTION_LOT` / `API_QUALITY_NOTIFICATION` | PROMAX → S/4 | Al cerrar `Inspeccion` con `estado != Aprobada` |
| Consulta stock / lote | `API_MATERIAL_STOCK` (GET) | PROMAX → S/4 | Al validar lote en kiosco / inspección |

**Idempotencia**: cada payload lleva `ExternalReference = promax:<entity>:<uuid>`; S/4HANA rechaza duplicados → PROMAX marca `s4_sync_status=OK` y guarda `s4_guid`.

**Mapeo de campos clave** (ejemplo `OrdenProduccion` → Production Order):
| PROMAX | S/4HANA (API_PRODUCTION_ORDER_2) |
|--------|----------------------------------|
| opPadre | `OrderID` (padre) |
| opNumero | `OrderID` (hija) |
| operacion | `Operation/Operation` |
| itemOP | `Material` |
| cantEjecutar | `OrderQuantity` |
| centroTrabajo.codigo | `WorkCenter` |
| fechaInicio | `BasicStartDate` |
| fechaFin | `BasicFinishDate` |

---

## 9. Despliegue en Cloud Foundry (SAP BTP)

### 9.1 `mta.yaml` (Multi-Target Application)

```yaml
_schema-version: '3.1'
ID: promax-mes
version: 1.0.0
description: PROMAX MES - Control de Piso

modules:
  - name: promax-db
    type: hdb
    path: db
    requires:
      - name: promax-hana
    parameters:
      memory: 256M
      disk-quota: 512M

  - name: promax-srv
    type: nodejs
    path: srv
    provides:
      - name: promax-srv_api
        properties:
          url: ${default-url}
    requires:
      - name: promax-hana
      - name: promax-uaa
      - name: s4-production-order
      - name: s4-maintenance
      - name: s4-quality
      - name: s4-material
    parameters:
      memory: 512M
      disk-quota: 512M
      buildpack: nodejs_buildpack
      command: cds run --with-mocks=false

  - name: promax-ui
    type: html5
    path: ui
    requires:
      - name: promax-srv_api
        group: destinations
        properties:
          name: promax-srv
          url: ~{url}
          forwardAuthToken: true
      - name: promax-uaa
    parameters:
      memory: 128M
      disk-quota: 128M

resources:
  - name: promax-hana
    type: org.cloudfoundry.managed-service
    parameters:
      service: hana
      service-plan: hdi-shared
      config: { schema: PROMAX_MES }

  - name: promax-uaa
    type: org.cloudfoundry.managed-service
    parameters:
      service: xsuaa
      service-plan: application
      path: xs-security.json

  - name: s4-production-order
    type: org.cloudfoundry.managed-service
    parameters:
      service: destination
      service-plan: lite
      config:
        name: s4-production-order
        url: https://<s4-host>/sap/opu/odata/sap/API_PRODUCTION_ORDER_2
        authentication: OAuth2ClientCredentials
        tokenServiceURL: https://<s4-auth>/oauth/token
        clientId: <from-communication-system>
        clientSecret: <from-communication-system>

  - name: s4-maintenance
    type: org.cloudfoundry.managed-service
    parameters:
      service: destination
      service-plan: lite
      config:
        name: s4-maintenance
        url: https://<s4-host>/sap/opu/odata/sap/API_MAINTNOTIFICATION
        authentication: OAuth2ClientCredentials
        ...

  - name: s4-quality
    type: org.cloudfoundry.managed-service
    parameters:
      service: destination
      service-plan: lite
      config:
        name: s4-quality
        url: https://<s4-host>/sap/opu/odata/sap/API_QUALITY_NOTIFICATION
        authentication: OAuth2ClientCredentials
        ...

  - name: s4-material
    type: org.cloudfoundry.managed-service
    parameters:
      service: destination
      service-plan: lite
      config:
        name: s4-material
        url: https://<s4-host>/sap/opu/odata/sap/API_MATERIAL_STOCK
        authentication: OAuth2ClientCredentials
        ...
```

### 9.2 `xs-security.json` (Roles)

```json
{
  "xsappname": "promax-mes",
  "tenant-mode": "dedicated",
  "scopes": [
    { "name": "$XSAPPNAME.Operario", "description": "Operario de piso" },
    { "name": "$XSAPPNAME.Supervisor", "description": "Supervisor de turno" },
    { "name": "$XSAPPNAME.Mantenimiento", "description": "Técnico mantenimiento" },
    { "name": "$XSAPPNAME.Calidad", "description": "Inspector calidad" },
    { "name": "$XSAPPNAME.Admin", "description": "Administrador sistema" }
  ],
  "role-templates": [
    { "name": "Operario", "scope-references": ["$XSAPPNAME.Operario"], "description": "Ejecuta producción/paros" },
    { "name": "Supervisor", "scope-references": ["$XSAPPNAME.Supervisor","$XSAPPNAME.Operario"], "description": "Ve dashboard, autoriza" },
    { "name": "Mantenimiento", "scope-references": ["$XSAPPNAME.Mantenimiento"], "description": "Gestiona WO, PM, activos" },
    { "name": "Calidad", "scope-references": ["$XSAPPNAME.Calidad"], "description": "Checklists, NC, CAPA" },
    { "name": "Admin", "scope-references": ["$XSAPPNAME.Admin"], "description": "Configuración total" }
  ]
}
```

### 9.3 Pipeline CI/CD (GitHub Actions)

```yaml
# .github/workflows/deploy.yml
on: [push, workflow_dispatch]
jobs:
  build-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - name: Install deps (monorepo)
        run: npm ci --workspaces=false
      - name: Build UI
        run: npm run build --workspace=promax-ui
      - name: Build CAP
        run: npm run build --workspace=promax-srv
      - name: Deploy to CF
        uses: SAP/cf-deploy-action@v2
        with:
          api: https://api.cf.us10-001.hana.ondemand.com
          org: ${{ secrets.CF_ORG }}
          space: ${{ secrets.CF_SPACE }}
          username: ${{ secrets.CF_USER }}
          password: ${{ secrets.CF_PASS }}
          manifest: mta.yaml
```

---

## 10. Seguridad y Cumplimiento

- **Autenticación**: XSUAA + JWT (RS256) — tokens de 1h, refresh 24h.
- **Autorización**: `@restrict` en CDS + checks en frontend (`usePermissions()`).
- **Datos sensibles**: `passwordHash` con bcrypt (12 rounds); secretos en **BTP Credential Store** (no en repo).
- **Cifrado**: TLS 1.3 en tránsito; HANA encryption at rest (default).
- **Auditoría**: tabla `AuditLog` (cds.audit) + headers `x-request-id` correlacionados frontend↔backend↔S/4.
- **RGPD / LGPD**: derecho al olvido → anonimización `Usuario` (soft delete + hash cédula); retención logs 2 años.

---

## 11. Testing & Calidad

| Nivel | Herramienta | Qué cubre |
|-------|-------------|-----------|
| Unit (backend) | Vitest + `@capire/test-utils` | Servicios CAP, mapeos S/4, cálculos OEE |
| Unit (frontend) | Vitest + React Testing Library | Hooks, componentes UI, lógica offline |
| Integración | Playwright (headed) | Flujos E2E: login → kiosko → paro → producción → sync S/4 mock |
| Contrato API | Pact / OpenAPI validation | CDS ↔ Frontend, CAP ↔ S/4 (mock server) |
| Carga | k6 | 200 operarios concurrentes, 50 paros/min, 100 confirmaciones/min |
| Accesibilidad | axe-core | WCAG 2.1 AA (contraste, foco, ARIA) |
| Seguridad | npm audit + Snyk + OWASP ZAP | Dependencias, headers, inyección |

**Mock S/4HANA en CI**: `@sap/cds-mock-server` con EDMX descargados del API Hub [43].

---

## 12. Observabilidad

- **Logs**: `pino` (JSON) → Cloud Logging (BTP) / Loki.
- **Métricas**: `prom-client` → Prometheus + Grafana (dashboards: RPS, latencia p95, errores 5xx, cola sync S/4, OEE tiempo real).
- **Trazas**: OpenTelemetry (auto-instrumentation Node.js + React) → Tempo/Jaeger.
- **Alertas**: 
  - `sync_s4_error_rate > 5%` 5min → PagerDuty/Teams.
  - `andon_unacked > 10min` → notificación push a Supervisor.
  - `db_pool_usage > 80%` → escala CF `promax-srv`.

---

## 13. Plan de Migración (Brownfield)

| Fase | Actividad | Duración | Responsable |
|------|-----------|----------|-------------|
| 0 | Levantamiento de gaps: comparar catálogos PROMAX actual vs CDS nuevo | 1 sem | PM + Architect |
| 1 | Setup repo monorepo (pnpm workspaces), CI/CD, BTP space | 1 sem | DevOps |
| 2 | CDS model + HANA deployment + XSUAA + Destinations | 2 sem | Backend |
| 3 | Frontend shell (auth, theme, routing, offline, WS) | 2 sem | Frontend |
| 4 | Módulo Centros + Operaciones + Paros + Producción (F1 core) | 4 sem | Full team |
| 5 | Dashboard Admin + Andon + Cargue Masivo automatizado | 2 sem | Frontend + Backend |
| 6 | Piloto 1 línea (2 semanas) — feedback operarios | 2 sem | QA + PM |
| 7 | Calidad (F2) + Mantenimiento (F3) | 8–10 sem | Full team |
| 8 | Migración datos históricos (SharePoint → HANA) | 2 sem | Backend |
| 9 | Corte productivo (paralelo 2 semanas → switch) | 2 sem | DevOps + PM |
| 10 | Hipercare + mejoras F4 | continuo | Team |

**Riesgos y mitigaciones**:
- **R**: S/4HANA APIs cambian versión → **M**: `cds import` automático en CI nocturno + tests de contrato.
- **R**: Red inestable en planta → **M**: Offline-first obligatorio; validación en piloto.
- **R**: Adopción operarios (cambio Power Apps → React) → **M**: UI idéntica en colores/flujos; capacitación 2h + "modo guiado" (tooltips paso a paso).
- **R**: Cargue masivo legacy falla → **M**: Mantener proceso manual paralelo 1 mes; comparar totales diarios.

---

## 14. Estimación de Esfuerzo (Story Points / Semanas)

| Épica | SP | Semanas (equipo 6) |
|-------|----|-------------------|
| Setup + Arquitectura | 21 | 2 |
| Auth + Maestros + Catálogos | 34 | 3 |
| Kiosco: Centros, Operaciones, Paros, Producción | 89 | 6 |
| Dashboard Admin + Andon + Cargue Masivo | 55 | 4 |
| Calidad (Checklist, Inspección, NC/CAPA) | 55 | 5 |
| Mantenimiento (Activos, PM, WO, Repuestos) | 68 | 6 |
| Integración S/4HANA (7 APIs, sync, retry, idempotencia) | 45 | 4 |
| Offline + PWA + WS tiempo real | 34 | 3 |
| Testing + Accesibilidad + Seguridad | 40 | 3 |
| Migración datos + Piloto + Corte | 30 | 3 |
| **Total** | **471** | **≈ 38 sem** (con solapamiento real ~28 sem) |

---

## 15. Próximos Pasos Inmediatos (Esta Semana)

1. **PM**: Crea épicas en GitHub Projects / Jira a partir de §7 y §14; asigna due dates.
2. **Architect**: Valida modelo CDS (§4) con DBA HANA; confirma namespaces, índices, particionado.
3. **Backend**: Inicializa monorepo `pnpm` con workspaces `db`, `srv`, `ui`; `cds init`; añade Remote Services (§5) y `mta.yaml` (§9).
4. **Frontend**: `npm create vite@latest promax-ui -- --template react-ts`; configura Tailwind con paleta §2; `AuthProvider` + `React Query` + `React Router` + `Socket.io-client`.
5. **DevOps**: Crea space CF `promax-prod`; provisiona HANA `promax-hana` + XSUAA + 4 Destinations (credenciales del Communication System S/4HANA del cliente).
6. **QA**: Escribe escenarios Gherkin para los 4 flujos core (login→kiosko→paro→producción→sync) y 2 flujos calidad/mantenimiento.

---

## Sources

[26] https://www.sepasoft.com/products/oee-downtime-tracking
[29] https://support.tulip.co/docs/what-is-tulip
[41] https://help.sap.com/docs/SAP_S4HANA_CLOUD/d35113ee62644d3abee1aaec148291d9/0a4262096d2e43258df27c594bdd1468.html
[42] https://help.sap.com/docs/SAP_S4HANA_CLOUD/d35113ee62644d3abee1aaec148291d9/e77b762e243b4045ad1f1f048f6aab87.html
[43] https://api.sap.com/products/SAPS4HANACloud/apis/ODATA
[44] https://help.sap.com/docs/SAP_S4HANA_CLOUD/f9ba73d1b8c543c2bd2ba1666271af86/f430cbb1950c4880810e27a8308db301.html
[45] https://help.sap.com/docs/SAP_S4HANA_CLOUD/2dfa044a255f49e89a3050daf3c61c11/66c2037d8541405886722cffe882050a.html
[46] https://cap.cloud.sap/docs/node.js/remote-services
[47] https://cap.cloud.sap/docs/guides/services/consuming-services
