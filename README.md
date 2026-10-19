# PROMAX — MES de Control de Piso (Producción · Calidad · Mantenimiento)

Sistema MES (Manufacturing Execution System) para plantas de manufactura metalmecánica: control de piso de producción, paros, calidad y sincronización con S/4HANA.

- **Frontend**: React (kiosco táctil para operarios + módulos admin), offline-first (IndexedDB/Dexie), tiempo real (WebSocket)
- **Backend**: SAP CAP (Node.js) — OData V4 + REST según `srv/openapi.yaml`
- **Base de datos**: SAP HANA Cloud (SAP BTP, cuenta trial)
- **Deploy**: SAP BTP Cloud Foundry (trial) — mismo patrón que `App_Turnos_SAP`

## Documentación y artefactos

| Archivo | Contenido |
|---|---|
| `docs/SPEC.md` | Especificación técnica por pantalla del MVP aprobado (11 pantallas: campos, validaciones, APIs, estados, offline, permisos) |
| `docs/stitch_prompt.md` | Prompt maestro para generar la UI en Google AI Studio / Stitch (enfoque funcional) |
| `docs/promax_nuevo_plan.md` | Plan de producto / roadmap |
| `db/schema.cds` | Modelo de datos CDS definitivo (entidades, asociaciones, vistas KPI) |
| `srv/openapi.yaml` | Contrato OpenAPI del backend (paths, schemas, seguridad) |
| `mockups/` | Mockups HTML aprobados: `login_v2.html`, `kiosk_v2.html` (estilo clásico Promax), `kiosk_v3.html` (variante kiosco táctil oscura) |

## Paleta PROMAX (tokens Tailwind `promax.*`)

```
primary: #3860B2 · header: #616161 · bg: #EDEDED · card: #FFFFFF · green: #57A84B
red: #FF0000 · teal: #2BA8AD · cyan: #48BBDD · navy: #0D2535 · navyLight: #0E202E
blue2: #005E92 · text: #1C1C1C · textMuted: #62686C · border: #C8C4C0 · focus: #3860B2
```

## Roles y permisos

| Rol | Acceso |
|-----|--------|
| Operario | Kiosco de centro de trabajo |
| Supervisor | + WIP, Dashboard, Orden Manual |
| Admin | Todo (Usuarios, Usuarios×Centro, Configuración) |

## Equipo de desarrollo (Hermes)

`pm` · `architect` · `backend` · `frontend` · `qa` · `devops` — cada rol toma los issues con su etiqueta en GitHub. Convención de ramas: `feat/<issue>-<slug>` → PR a `main`.

## Sprint 0

Los issues #1–#6 contienen las tareas de arranque (esqueleto CAP, CI, servicios base, base React, plan de pruebas y backlog). Base técnica: reutilizar el esqueleto de [App_Turnos_SAP](https://github.com/Juliancho92/App_Turnos_SAP) desplegado en la cuenta BTP trial.
