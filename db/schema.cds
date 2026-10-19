namespace promax.mes;

using { managed, cuid, temporal } from '@sap/cds/common';

// ============================================================================
// MAESTROS ORGANIZACIONALES
// ============================================================================

entity Planta : managed {
  key codigo      : String(10);
  nombre          : String(80);
  pais            : String(3) default 'COL';
  zonaHoraria     : String(40) default 'America/Bogota';
  activa          : Boolean default true;
}

entity Linea : managed {
  key codigo      : String(20);
  nombre          : String(80);
  planta          : Association to Planta;
  activa          : Boolean default true;
}

entity CentroTrabajo : managed {
  key codigo            : String(30);
  nombre                : String(100);
  linea                 : Association to Linea;
  grupo                 : String(20);           // ej. CORTE_CALIENTE, ENSAMBLE, MAQUINADO
  divisionTiempo        : String(20);           // para cálculos UnoE
  bodegaCT              : String(20);           // bodega por defecto
  centroAnterior        : Association to CentroTrabajo; // flujo secuencial
  activo                : Boolean default true;
  // Sync S/4HANA
  s4_sync_status        : String(20) default 'PENDING'; // PENDING, OK, ERROR
  s4_sync_ts            : DateTime;
  s4_guid               : String(36);
}

entity Turno : managed {
  key codigo          : String(10);
  nombre              : String(40);
  planta              : Association to Planta;
  horaInicio          : Time;
  horaFin             : Time;
  diasAplicable       : String(50); // L-V, S, D/F
  activo              : Boolean default true;
}

entity Calendario : managed {
  key fecha           : Date;
  turno               : Association to Turno;
  esLaborable         : Boolean default true;
  planta              : Association to Planta;
}

// ============================================================================
// USUARIOS Y SEGURIDAD
// ============================================================================

entity Usuario : managed {
  key id              : String(20); // cédula
  nombre              : String(100);
  email               : String(120);
  telefono            : String(30);
  passwordHash        : String(255); // bcrypt 12 rounds
  rol                 : String(20);  // Operario, Supervisor, Mantenimiento, Calidad, Admin
  activo              : Boolean default true;
  // Sync S/4HANA (futuro SSO)
  s4_sync_status      : String(20) default 'PENDING';
  s4_sync_ts          : DateTime;
  s4_guid             : String(36);
}

entity UsuarioCentro : managed {
  key usuario         : Association to Usuario;
  key centro          : Association to CentroTrabajo;
  habilitado          : Boolean default true;
  asignadoEn          : DateTime default now();
}

entity Habilidad : managed {
  key codigo          : String(30);
  nombre              : String(80);
  descripcion         : String(200);
}

entity UsuarioHabilidad : managed {
  key usuario         : Association to Usuario;
  key habilidad       : Association to Habilidad;
  nivel               : Integer default 1; // 1-5
  vencimiento         : Date;
  certificado         : Boolean default false;
}

// ============================================================================
// CATÁLOGOS OPERATIVOS
// ============================================================================

entity TipoParo : managed {
  key codigo          : String(20);
  descripcion         : String(100);
  tipo                : String(20); // Planificado, NoPlanificado
  tipohora            : String(20); // para UnoE
  categoria           : String(30); // Mecanico, Electrico, Calidad, Logistica, etc.
  requiereMotivo      : Boolean default true;
  color               : String(7) default '#FF0000'; // hex para UI
  activo              : Boolean default true;
}

entity MotivoRechazo : managed {
  key id              : String(20);
  descripcion         : String(120);
  activo              : Boolean default true;
}

entity TipoActividad : managed {
  key codigo          : String(20);
  descripcion         : String(100);
  categoria           : String(30); // Produccion, Paro, PuestaPunto, Ajuste, Limpieza
  esProductiva        : Boolean default false;
  activo              : Boolean default true;
}

entity CodigoOperacion : managed {
  key codigo          : String(30);
  descripcion         : String(120);
  tipoActividad       : Association to TipoActividad;
  centroTrabajo       : Association to CentroTrabajo; // opcional, filtro por centro
  activo              : Boolean default true;
}

// ============================================================================
// ÓRDENES Y OPERACIONES
// ============================================================================

entity OrdenProduccion : managed {
  key opPadre           : String(30);
  key opNumero          : String(30);
  key operacion         : String(30);

  itemOP                : String(40);
  itemOPRef             : String(40);
  itemOPResumen         : String(200);
  estado                : String(20); // Aprobada, EnProceso, Completada, Cancelada, Borrador
  fechaInicio           : DateTime;
  fechaFin              : DateTime;
  fechaDocumento        : DateTime;
  cantEjecutar          : Decimal(15,3);
  cantPendiente         : Decimal(15,3);
  cantCompleta          : Decimal(15,3) default 0;
  cantRetrabajo         : Decimal(15,3) default 0;
  cantRechazos          : Decimal(15,3) default 0;
  centroTrabajo         : Association to CentroTrabajo;
  bodega                : String(20);
  linea                 : Association to Linea;
  claseOP               : String(20); // UNICA, COMPONENTE, RETRABAJO
  opReferencial         : String(30);
  notas                 : String(500);
  pesoEnKls             : Decimal(15,3);
  cantidadEjecutarKls   : Decimal(15,3);
  // Origen
  origenManual          : Boolean default false; // true = creada en app, false = sincronizada S/4
  // Sync S/4HANA
  s4_sync_status        : String(20) default 'PENDING';
  s4_sync_ts            : DateTime;
  s4_guid               : String(36);
  s4_error_msg          : String(500);
}

entity OperacionOrden : managed {
  key orden             : Association to OrdenProduccion;
  key numeroOperacion   : Integer;
  codigoOperacion       : Association to CodigoOperacion;
  centroTrabajo         : Association to CentroTrabajo;
  cantPlaneada          : Decimal(15,3);
  cantCompleta          : Decimal(15,3) default 0;
  estado                : String(20); // Pendiente, EnProceso, Completada, Saltada
  // Sync
  s4_sync_status        : String(20) default 'PENDING';
  s4_sync_ts            : DateTime;
  s4_guid               : String(36);
}

// ============================================================================
// EJECUCIÓN EN PISO — REGISTROS DE TIEMPRO
// ============================================================================

entity RegistroProduccion : managed {
  key id                : UUID;

  orden                 : Association to OrdenProduccion;
  operacion             : Association to OperacionOrden;
  centroTrabajo         : Association to CentroTrabajo;
  operario              : Association to Usuario;
  turno                 : Association to Turno;
  fecha                 : DateTime;

  horaInicio            : DateTime;
  horaFin               : DateTime;
  duracionSeg           : Integer; // calculado: horaFin - horaInicio

  piezasConformes       : Decimal(15,3) default 0;
  piezasNoConformes     : Decimal(15,3) default 0;
  lote                  : String(40);
  paquete               : String(40);
  requerimiento         : String(40);

  tipoHora              : String(20); // Produccion, Paro, PuestaPunto, Ajuste
  tipoActividad         : Association to TipoActividad;
  codigoOperacion       : Association to CodigoOperacion;
  motivoRechazo         : Association to MotivoRechazo;
  motivoLibre           : String(200);

  // KPIs calculados (persistidos para consultas rápidas)
  oee_disponibilidad    : Decimal(5,2);
  oee_desempeno         : Decimal(5,2);
  oee_calidad           : Decimal(5,2);
  oee_global            : Decimal(5,2);

  // Sync S/4HANA
  s4_sync_status        : String(20) default 'PENDING';
  s4_sync_ts            : DateTime;
  s4_guid               : String(36);
  s4_error_msg          : String(500);

  // Offline
  offline_id            : String(50); // UUID generado en cliente
  offline_ts            : DateTime;
}

entity RegistroParo : managed {
  key id                : UUID;

  registroProduccion    : Association to RegistroProduccion; // encadenamiento
  orden                 : Association to OrdenProduccion;
  centroTrabajo         : Association to CentroTrabajo;
  operario              : Association to Usuario;
  turno                 : Association to Turno;
  fecha                 : DateTime;

  horaInicio            : DateTime;
  horaFin               : DateTime;
  duracionSeg           : Integer;

  tipoParo              : Association to TipoParo;
  codigoOperacion       : Association to CodigoOperacion;
  motivoLibre           : String(200);
  esPlanificado         : Boolean; // derivado de tipoParo.tipo

  // Detección automática (Fase 2)
  autoDetectado         : Boolean default false;
  sensorDataJson        : String(2000); // snapshot sensores al momento

  // Sync S/4HANA (notificación mantenimiento)
  s4_sync_status        : String(20) default 'PENDING';
  s4_sync_ts            : DateTime;
  s4_guid               : String(36); // GUID notificación mantenimiento
  s4_error_msg          : String(500);

  // Offline
  offline_id            : String(50);
  offline_ts            : DateTime;
}

// ============================================================================
// CALIDAD (Fase 2 - entidad lista, feature flag)
// ============================================================================

entity PlantillaChecklist : managed {
  key id                : UUID;
  nombre                : String(100);
  version               : Integer default 1;
  activa                : Boolean default true;
  aplicaACentro         : Association to CentroTrabajo;
  aplicaAItem           : String(40);
  jsonLogic             : String(5000); // lógica condicional (jsonlogic.js)
  createdBy             : Association to Usuario;
}

entity Inspeccion : managed {
  key id                : UUID;
  orden                 : Association to OrdenProduccion;
  operacion             : Association to OperacionOrden;
  plantilla             : Association to PlantillaChecklist;
  inspector             : Association to Usuario;
  centroTrabajo         : Association to CentroTrabajo;
  fecha                 : DateTime;
  estado                : String(20); // EnProceso, Aprobada, Rechazada, Hold
  resultadosJson        : String(10000); // respuestas + fotos base64/URLs
  holdHasta             : DateTime;
  // Sync
  s4_sync_status        : String(20) default 'PENDING';
  s4_sync_ts            : DateTime;
  s4_guid               : String(36);
}

entity NoConformidad : managed {
  key id                : UUID;
  inspeccion            : Association to Inspeccion;
  lote                  : String(40);
  descripcion           : String(500);
  motivoRechazo         : Association to MotivoRechazo;
  severidad             : String(20); // Leve, Mayor, Critica
  responsable           : Association to Usuario;
  fechaApertura         : DateTime default now();
  fechaCierre           : DateTime;
  estado                : String(20); // Abierta, EnAnalisis, Cerrada
  accionCorrectiva      : String(2000);
  accionPreventiva      : String(2000);
  eficaciaVerificada    : Boolean default false;
  fechaVerificacion     : DateTime;
}

// ============================================================================
// MANTENIMIENTO (Fase 3 - entidad lista, feature flag)
// ============================================================================

entity Activo : managed {
  key codigo            : String(40);
  nombre                : String(120);
  centroTrabajo         : Association to CentroTrabajo;
  jerarquiaPadre        : Association to Activo;
  tipo                  : String(30); // Maquina, Herramienta, Instalacion
  numeroSerie           : String(60);
  fabricante            : String(80);
  modelo                : String(80);
  fechaInstalacion      : DateTime;
  ubicacionFisica       : String(100);
  qrCode                : String(200);
  medidorHoras          : Decimal(15,2) default 0;
  medidorCiclos         : Decimal(15,2) default 0;
  ultimaLectura         : DateTime;
  critico               : Boolean default false;
  // Sync
  s4_sync_status        : String(20) default 'PENDING';
  s4_sync_ts            : DateTime;
  s4_guid               : String(36);
}

entity PlanMantenimiento : managed {
  key id                : UUID;
  activo                : Association to Activo;
  nombre                : String(100);
  tipo                  : String(20); // Calendario, MedidorHoras, MedidorCiclos, Condicion
  frecuenciaDias        : Integer;
  frecuenciaHoras       : Decimal(15,2);
  frecuenciaCiclos      : Decimal(15,2);
  toleranciaDias        : Integer default 0;
  proximaEjecucion      : DateTime;
  activoFlag            : Boolean default true;
  checklist             : Association to PlantillaChecklist;
  responsableRol        : String(20);
  // Sync
  s4_sync_status        : String(20) default 'PENDING';
  s4_sync_ts            : DateTime;
  s4_guid               : String(36);
}

entity OrdenTrabajoMant : managed {
  key id                : UUID;
  plan                  : Association to PlanMantenimiento;
  activo                : Association to Activo;
  tipo                  : String(20); // Preventiva, Correctiva, Predictiva, Mejora
  prioridad             : String(10); // Alta, Media, Baja
  solicitante           : Association to Usuario;
  asignadoA             : Association to Usuario;
  fechaCreacion         : DateTime default now();
  fechaProgramada       : DateTime;
  fechaInicio           : DateTime;
  fechaFin              : DateTime;
  estado                : String(20); // Abierta, Asignada, EnProceso, Pausada, Completada, Cancelada
  descripcion           : String(1000);
  causaRaiz             : String(1000);
  accionTomada          : String(2000);
  tiempoRealHoras       : Decimal(8,2);
  costoMateriales       : Decimal(15,2);
  costoManoObra         : Decimal(15,2);
  // Sync S/4HANA
  s4_sync_status        : String(20) default 'PENDING';
  s4_sync_ts            : DateTime;
  s4_guid               : String(36);
}

entity Repuesto : managed {
  key codigo            : String(40);
  nombre                : String(120);
  unidad                : String(10);
  stockMin              : Decimal(15,3) default 0;
  stockActual           : Decimal(15,3) default 0;
  ubicacionBodega       : String(20);
  costoUnitario         : Decimal(15,2);
  critico               : Boolean default false;
}

entity MovimientoRepuesto : managed {
  key id                : UUID;
  repuesto              : Association to Repuesto;
  ordenTrabajo          : Association to OrdenTrabajoMant;
  tipo                  : String(10); // Salida, Entrada, Ajuste, Transferencia
  cantidad              : Decimal(15,3);
  fecha                 : DateTime default now();
  responsable           : Association to Usuario;
  lote                  : String(40);
}

// ============================================================================
// ANDON / EVENTOS
// ============================================================================

entity AndonEvent : managed {
  key id                : UUID;
  centroTrabajo         : Association to CentroTrabajo;
  tipo                  : String(20); // Paro, Calidad, Mantenimiento, Seguridad, Material
  severidad             : String(10); // Baja, Media, Alta, Critica
  mensaje               : String(500);
  creadoPor             : Association to Usuario;
  creadoEn              : DateTime default now();
  atendidoPor           : Association to Usuario;
  atendidoEn            : DateTime;
  resuelto              : Boolean default false;
  resueltoEn            : DateTime;
  tiempoRespuestaSeg    : Integer;
  // Sync
  s4_sync_status        : String(20) default 'PENDING';
  s4_sync_ts            : DateTime;
}

// ============================================================================
// AUDITORÍA
// ============================================================================

entity AuditLog : managed {
  key id                : UUID;
  usuarioId             : String(20);
  accion                : String(50); // CREATE, UPDATE, DELETE, LOGIN, LOGOUT, SYNC
  entidad               : String(50);
  entidadId             : String(100);
  timestamp             : DateTime default now();
  diff                  : LargeString; // JSON del before/after
  ip                    : String(45);
  userAgent             : String(200);
  resultado             : String(20); // SUCCESS, ERROR
  errorMsg              : String(500);
}

// ============================================================================
// CONFIG / FEATURE FLAGS
// ============================================================================

entity Configuracion : managed {
  key clave             : String(50);
  valor                 : String(500);
  tipo                  : String(20); // STRING, NUMBER, BOOLEAN, JSON
  descripcion           : String(200);
  editable              : Boolean default true;
}

// ============================================================================
// VISTAS PARA KPIs Y REPORTES
// ============================================================================

@cds.autoexpose
view OEECalculado as select from RegistroProduccion
  join CentroTrabajo as CT on CT.codigo = centroTrabajo.codigo
  join Turno as T on T.codigo = turno.codigo
  join OrdenProduccion as OP on OP.opNumero = orden.opNumero
{
  CT.codigo           as centro,
  CT.nombre           as centroNombre,
  fecha,
  T.codigo            as turno,
  sum(case when tipoHora = 'Produccion' then duracionSeg else 0 end) as t_produccion,
  sum(case when tipoHora = 'Paro' then duracionSeg else 0 end) as t_paro,
  sum(case when tipoHora in ('PuestaPunto','Ajuste') then duracionSeg else 0 end) as t_setup,
  sum(piezasConformes) as good,
  sum(piezasNoConformes) as scrap,
  sum(piezasConformes) / nullif(sum(piezasConformes) + sum(piezasNoConformes), 0) * 100 as calidad_pct,
  // OEE componentes
  (1 - sum(case when tipoHora = 'Paro' then duracionSeg else 0 end) / nullif(sum(duracionSeg),0)) * 100 as disponibilidad_pct,
  sum(piezasConformes) / nullif(sum(case when tipoHora = 'Produccion' then duracionSeg else 0 end) * 1.0, 0) * 100 as desempeno_pct
}
group by CT.codigo, CT.nombre, fecha, T.codigo;

@cds.autoexpose
view WIP_SyncStatus as select from RegistroProduccion
  union all select from RegistroParo
  union all select from OrdenTrabajoMant
  union all select from Inspeccion
  union all select from NoConformidad
  union all select from AndonEvent
{
  key id,
  'RegistroProduccion'  as entityType,
  centroTrabajo.codigo  as centro,
  fecha,
  s4_sync_status,
  s4_sync_ts,
  s4_guid,
  s4_error_msg,
  createdAt
}
union all
{
  key id,
  'RegistroParo'        as entityType,
  centroTrabajo.codigo  as centro,
  fecha,
  s4_sync_status,
  s4_sync_ts,
  s4_guid,
  s4_error_msg,
  createdAt
}
union all
{
  key id,
  'OrdenTrabajoMant'    as entityType,
  activo.centroTrabajo.codigo as centro,
  fechaCreacion         as fecha,
  s4_sync_status,
  s4_sync_ts,
  s4_guid,
  s4_error_msg,
  createdAt
}
union all
{
  key id,
  'Inspeccion'          as entityType,
  centroTrabajo.codigo  as centro,
  fecha,
  s4_sync_status,
  s4_sync_ts,
  s4_guid,
  s4_error_msg,
  createdAt
}
union all
{
  key id,
  'NoConformidad'       as entityType,
  inspeccion.centroTrabajo.codigo as centro,
  fechaApertura         as fecha,
  s4_sync_status,
  s4_sync_ts,
  s4_guid,
  s4_error_msg,
  createdAt
}
union all
{
  key id,
  'AndonEvent'          as entityType,
  centroTrabajo.codigo  as centro,
  creadoEn              as fecha,
  s4_sync_status,
  s4_sync_ts,
  s4_guid,
  cast(null as String(500)) as s4_error_msg,
  createdAt
};

// ============================================================================
// ANOTACIONES PARA OPEN API / FIORI
// ============================================================================

annotate promax.mes.OrdenProduccion with @odata.draft.enabled;
annotate promax.mes.RegistroProduccion with @odata.draft.enabled;
annotate promax.mes.RegistroParo with @odata.draft.enabled;

annotate promax.mes.Usuario with @(Common.FieldControl.ReadOnly : false);
annotate promax.mes.Usuario.passwordHash with @Common.FieldControl.Hidden;