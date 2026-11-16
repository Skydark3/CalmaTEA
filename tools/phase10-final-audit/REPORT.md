# FASE 10 — auditoría final previa a Firebase real

> Candidato de reglas superado por la auditoría de integridad posterior:
> `tools/phase10-activity-integrity/REPORT.md`. No desplegar el antiguo
> `tools/phase10-final-audit/deploy.rules.json`, que no incorpora el tipo
> inmutable ni la prohibición de borrado físico de activities. El respaldo y
> este informe se conservan como evidencia histórica.

## Actualización posterior: cierre con actividad terminal (2026-10-31)

La incompatibilidad de cierre por cambio de status descrita en la auditoría
histórica inferior quedó corregida **localmente**. `completeSession()` ya no
lee `activities` desde el SDK infantil: utiliza la sesión y el bloqueo; las
reglas existentes verifican internamente tipo y vínculos. No se modificaron
`firestore.rules`, índices, modelos ni permisos de lectura. Los nuevos inicios
validan también la configuración con el factory existente. Se mantiene el
rechazo de nuevas sesiones de actividades completed/cancelled y la recuperación
del mismo sessionId existente, no una ejecución adicional.

Validación posterior: Flutter Analyze sin problemas; Flutter 457/457; Firestore
Rules 30/30 y auditoría adicional 5/5; FASE 10 E2E 12/12 suites (la de bloqueo
incluye ahora 17 casos); Android 2/2 en Medium_Phone_API_37.0. Android recorre los
ocho motores, ambos cambios de status, interrupción, configuraciones vacías,
resultado único y protección de un bloqueo posterior. El corte de conexión se
valida mediante un proxy TCP de pruebas en loopback, no suponiendo que
`disableNetwork()` corta las transacciones nativas. Se comprobó desde el cliente
profesional que la sesión sigue inProgress y no existe resultado parcial durante
el corte; al reconectar se reintenta el mismo sessionId. Los fallos antes/después
del commit también tienen pruebas Dart deterministas.

Para reproducir Android, con JBR y el AVD preparados:

```powershell
firebase.cmd emulators:exec --only auth,firestore --project demo-calmatea-local "npm.cmd --prefix firestore-rules-test run seed && npm.cmd --prefix firestore-rules-test run test:android"
```

Este runner aporta los puertos 8090/8091 solo en loopback y falla si el entorno
no es demo-calmatea-local. No se utiliza en la aplicación ni modifica sus flags.
Se estabilizó el test UI para comprobar la ruta actual y los controles reales
de cada motor, en lugar de contar títulos de rutas superpuestas. El SDK Android
puede envolver rechazos transaccionales como unknown; las lecturas directas y
las pruebas de reglas siguen comprobando permission-denied y ausencia de nuevas
sesiones/bloqueos. No se modificó el tratamiento de errores de la aplicación.

La eliminación de la actividad o el cambio de su tipo durante una sesión siguen
fuera de esta corrección: las reglas rechazan vínculos/tipos que ya no coincidan.
No se migraron datos existentes. Firebase real sigue sin modificaciones y la
publicación/activación requieren otra autorización. Lo que sigue es el informe
original, conservado como evidencia histórica anterior a esta corrección.

Fecha: 2026-10-31 (America/Bogota). Proyecto revisado: `calmatea-4c781`, base `(default)`, Firestore Standard. Pruebas Firebase exclusivamente en `demo-calmatea-local`.

## Alcance y cambios locales

No se modificaron código Flutter, reglas locales, índices locales, flags, cuentas ni documentos. No se ejecutaron despliegues, compilaciones Android ni operaciones Git. Solo se añadieron herramientas, fixtures locales de auditoría, documentos y respaldos en `tools/phase10-final-audit/`. Los logs de herramientas se regeneran al ejecutar pruebas.

La consulta de configuración de producción usó ADC. Todas las operaciones contra las API de configuración fueron GET. No se leyeron documentos de aplicación ni credenciales internas de Firebase CLI; tokens permanecieron en memoria y no forman parte del respaldo. El intercambio OAuth de ADC no modifica configuración Firebase.

## Configuración publicada y comparación exacta

Release: `projects/calmatea-4c781/releases/cloud.firestore`.

Ruleset publicado: `projects/calmatea-4c781/rulesets/e906613f-fbdc-43c0-abbc-d548cfeeac45`.

Última actualización publicada: `2026-10-08T18:50:32.162159Z` (13:50:32 UTC-5).

SHA-256 de la fuente publicada: `d3d6661464da65f0101bbc1304e1c452527f57d59216be8ec4e52d8cfe77029e`.

SHA-256 de la propuesta local: `3558adfbaa08e23a736b9ea20835114426c49a0c542a58ddf5a8ff3229b5ff0a`.

Se comprobó que la release no cambió durante la captura. Los ocho archivos del respaldo se verifican mediante `published-2026-10-31/manifest.json`. El archivo normalizado `firestore.indexes.json` es derivado; las respuestas exactas del servidor se conservan separadamente en `indexes.published.json` y `fields.published.json`.

Comparación reproducible: `node tools/phase10-final-audit/compare-config.cjs`. Falla si cambia un hash del respaldo, si los cinco bloques existentes difieren o si cambia la propuesta congelada.

| Bloque | Publicado frente a propuesta |
| --- | --- |
| users | Idéntico byte por byte; perfil propio; sin actualización/eliminación |
| psychologists | Idéntico byte por byte; permisos previos conservados |
| children | Idéntico byte por byte; psicólogo propietario, no lectura infantil |
| therapies | Idéntico byte por byte; ownership e identidad inmutables |
| activities | Idéntico byte por byte; niño solo actividades propias assigned/inProgress |
| sessions | Sustituye la denegación recursiva por acceso controlado a documentos de primer nivel |
| activityResults | Sustituye la denegación recursiva por creación atómica y lectura restringida |
| activeExecutionSessions | Nuevo bloque; producción lo deniega por defecto |
| Subcolecciones y rutas restantes | Continúan denegadas por defecto |

`isAuthenticated` e `isOwner`, utilizados por los módulos existentes, son idénticos. Los cuatro helpers nuevos (`isAuthenticatedPsychologistUser`, `isAuthenticatedLinkedChildUser`, `linkedChildProfileMatches`, `isNonEmptyId`) se usan para las nuevas colecciones. Diff completo: `rules.published-to-proposed.diff`; comprobación y hashes: `comparison.json`.

## Mínimo privilegio y bloqueo

- Inicio: niño autenticado con perfil child vinculado; activityId, therapyId, childId y psychologistId deben coincidir con la actividad autorizada. Se exige timestamp del servidor e identidad inmutable.
- El inicio crea sesión y bloqueo en la misma transacción. La ruta determinista del bloqueo impide un segundo bloqueo por paciente; `update` y `list` del bloqueo están denegados.
- Reabrir la misma actividad recupera la misma sesión para la misma cuenta. Dos dispositivos de esa cuenta pueden recuperar la misma sesión: no es una exclusión física de pantallas, sino unicidad de sesión y resultado. La primera finalización válida gana.
- Otra actividad produce conflicto. Solo la confirmación de la UI interrumpe primero la sesión antigua; no existe cierre automático por tiempo. Las reglas verifican identidad/transición, no pueden demostrar que un humano aceptó un diálogo.
- Cierre: la sesión debe seguir inProgress y poseer exactamente el bloqueo actual. Se comparan sessionId, activityId, childId, psychologistId, childUserId y startedAt. La transacción no puede borrar el bloqueo de otra sesión ni de otro paciente.
- Finalización: completed + resultado con ID igual al sessionId + eliminación del bloqueo en la misma escritura atómica. El resultado es inmutable, con esquema cerrado de métricas agregadas y sin notas, respuestas detalladas ni datos clínicos libres.
- Interrupción: interrupted + eliminación del bloqueo exacto; no crea resultados.
- Solo el niño propietario y el psicólogo identificado por psychologistId pueden leer sesiones/resultados. El profesional no puede escribirlos ni leer/modificar el bloqueo.
- Un bloqueo terminal coherente puede liberarse de forma idempotente. Uno corrupto o cuya sesión falta falla cerrado; no se borra arbitrariamente.

## Consultas e índices

Producción: cero índices compuestos. La API devolvió únicamente la política automática `__default__/*` (ASC/DESC/CONTAINS), no excepciones de campos. No es una excepción que deba redesplegarse.

Único índice compuesto propuesto, aún ausente:

`sessions` / COLLECTION: `psychologistId ASC`, `childId ASC`, `startedAt DESC` (Firestore añade `__name__` implícitamente).

Es el índice de historial paginado (`limit(20)`, cursor). Sesión, resultado y bloqueo usan lecturas por ID. Los streams profesionales filtran por igualdad y ordenan en Dart. Las cuatro métricas usan psychologistId y, salvo total, igualdad de status. Con la política automática actual no se identifica otro índice compuesto necesario. Las consultas de solo igualdad pueden utilizar combinación de índices: https://firebase.google.com/docs/firestore/query-data/index-overview#use_index_merging.

El Emulator Suite no acredita por sí mismo que un índice compuesto esté construido en producción; será obligatorio esperar READY y comprobar el historial tras una autorización posterior. No se ejecutaron consultas de documentos ni agregaciones contra producción durante esta auditoría.

## Preview y flags

Preview evita el coordinador transaccional y entrega implementaciones efímeras explícitas a los ocho motores. No depende de sessions, activityResults ni activeExecutionSessions; no altera estados administrativos. La suite Flutter conserva pruebas de finalización efímera y de ausencia de llamadas al coordinador.

Los flags se validan como literales exactos true/false. Los cuatro flags funcionales están apagados por defecto. Preview y ejecución persistente no pueden estar activos simultáneamente. En release las funcionalidades quedan desactivadas. `USE_FIREBASE_EMULATORS` solo selecciona entorno y es independiente de los permisos/flags.

Control: flags de compilación, no Remote Config ni autorización de Firestore. Publicar reglas habilitaría el backend para todas las cuentas child que cumplan las condiciones, no solamente una cuenta piloto. No existe allowlist de piloto en servidor ni un interruptor remoto. Antes de activar hay que revisar qué builds persistentes están en uso y distribuir la prueba solo a las cuentas autorizadas.

## Riesgos confirmados, sin corrección silenciosa

1. **Cambio administrativo durante la ejecución.** `ActivityExecutionSessionService.completeSession()` lee el documento de actividad antes de guardar. Si el profesional cambia su status a completed/cancelled, las reglas existentes de activities deniegan ese GET infantil. Aunque las reglas nuevas admiten un cierre atómico bien formado, el cliente no llega a emitirlo. El test adicional reproduce el GET denegado y verifica que la interrupción aún libera el bloqueo. El listado infantil tampoco permite reabrir una actividad ya ocultada. No ampliar permisos de activities como parche. Para piloto, mantener actividad assigned/inProgress sin editarla durante la ejecución. Para habilitación general, autorizar una corrección explícita del flujo de cierre/recuperación y probarla con el servicio Dart real.
2. **Eliminaciones y cambios de configuración.** El historial depende de que la actividad siga existiendo y del tipo actual; borrar la actividad o cambiar su tipo durante una sesión puede impedir guardar o visualizar resultados. No se modificó la política CRUD previa. Congelar cambios administrativos durante el piloto; definir después política de conservación/versionado con autorización.
3. **Conectividad.** Las transacciones requieren conexión; inicio/guardado pueden fallar. Los motores muestran estados de error y reintento y no anuncian guardado hasta confirmarlo. El preflight y los bloqueos corruptos muestran un error genérico (`No pudimos preparar esta actividad.`), sin código Firebase ni datos sensibles, pero sin una guía específica de reparación. Un bloqueo corrupto requiere soporte administrativo autorizado; no hay reparación masiva.
4. **Recuperación limitada.** Se recupera la sesión, no el progreso interno del ejercicio. Reiniciar después de una respuesta de red ambigua no preserva cada interacción; los reintentos de cierre dentro de la misma sesión no duplican resultados. No hay checkpoint del motor ni solución completa de UX multi-dispositivo.
5. **Métricas.** Los cuatro count() no comparten snapshot; existe comprobación de coherencia y un reintento. Son indicadores descriptivos, no una instantánea transaccional global ni conclusiones clínicas.
6. **Control del piloto.** Los flags son por build. Apagarlos requiere detener/recompilar/reabrir el Debug; la reversión de reglas es la contención del lado servidor. No confiar en los flags como permisos.

## Validaciones ejecutadas el 2026-10-31

- `flutter analyze`: sin problemas, exit 0.
- `flutter test`: 434/434, exit 0.
- Firestore Rules baseline: 26/26, exit 0.
- Auditoría adicional: 5/5 (no sustituyen ni reducen el baseline).
- FASE 10 E2E: 12/12 suites, exit 0, incluidos ocho motores, historial, métricas, integral y bloqueo/concurrencia.
- Flags compilados: 9/9 con emuladores y funcionalidades persistentes explícitas, y 9/9 con Preview independiente y persistencia apagada. Son tests de configuración, sin inicializar Firebase ni lanzar la aplicación; no se suman al baseline 434.
- Todas las pruebas Firebase anteriores se ejecutaron mediante `emulators:exec --project demo-calmatea-local --only auth,firestore`.
- Android integral no repetido: no cambió código Flutter, reglas de aplicación ni flags. El 1/1 del 2026-10-30 sigue siendo antecedente, no una ejecución nueva de hoy.
- Log de Firestore: cero coincidencias de advertencias del límite de 1000 expresiones y de límites de acceso documental. No se afirma un número exacto instrumentado por solicitud. Hay rechazos PERMISSION_DENIED esperados, contención `entity already exists` y tres líneas `Null value error` de una prueba negativa que intenta borrar un bloqueo inexistente; no son fallos válidos de permisos ni advertencias de límite.
- JBR 25 de Android Studio se eligió solo para estos procesos, sin modificar configuración global. No se actualizó Flutter ni dependencias.

## Respaldo y reversión (PREPARADO, NO EJECUTADO)

`published-2026-10-31/` contiene fuente exacta, release/ruleset originales, configuración de base e índices y manifiesto SHA-256. No es un respaldo de documentos ni autoriza borrarlos. Antes de desplegar, verificar de nuevo hashes y release/indexes actuales; si hubo cambios concurrentes, detenerse y volver a comparar.

Lectura de verificación sin sobrescribir el respaldo: `node tools/phase10-final-audit/read-production-config.cjs --verify` (requiere ADC y red; solo GET). Detiene el proceso si cambió la release, la fuente de reglas, los índices o la política de campos.

Los JSON de despliegue usan rutas absolutas a las copias congeladas, omiten Functions/Storage/Hosting y no alteran firebase.json ni .firebaserc. Comandos PowerShell que requieren OTRA autorización, desde C:\TEA:

```powershell
# 0. Verificación local; este sí es de solo lectura/rematerialización local.
node tools/phase10-final-audit/compare-config.cjs

# 1. DESPLIEGUE FUTURO DE ÍNDICES: no ejecutado.
firebase.cmd deploy --project calmatea-4c781 --config C:/TEA/tools/phase10-final-audit/deploy.indexes.json --only firestore:indexes

# 2. Esperar READY y volver a verificar proyecto/release. DESPLIEGUE FUTURO DE REGLAS: no ejecutado.
firebase.cmd deploy --project calmatea-4c781 --config C:/TEA/tools/phase10-final-audit/deploy.rules.json --only firestore:rules

# CONTENCIÓN / REVERSIÓN FUTURA: restaura solo las reglas guardadas, sin tocar documentos.
firebase.cmd deploy --project calmatea-4c781 --config C:/TEA/tools/phase10-final-audit/rollback.rules.json --only firestore:rules
```

No usar `firebase deploy` sin `--only`, `--force` ni aceptar eliminación de índices inesperada. El JSON normalizado de índices publicados es referencia de respaldo, no una orden de borrado.

Reversión: detener el Debug persistente; restaurar las reglas anteriores con autorización de contingencia; comprobar fuente publicada mediante GET; volver a flags apagados/Preview. Conservar sesiones y resultados que ya se hayan creado y el índice nuevo (inocuo para permisos). Restaurar reglas antiguas los hace inaccesibles para clientes, pero **no** elimina datos ni libera bloqueos. Una limpieza/eliminación de índices o reparación de sesiones requiere autorización aparte. El rollback de reglas no revierte escrituras ya confirmadas y los listeners pueden tardar en reflejar cambios; verificar denegación desde un cliente nuevo antes de declarar contención completa.

## Orden de aprobación y prueba Android controlada

1. Revisar estos riesgos. Preferible resolver la limitación de cambio de estado antes de habilitación general. Un piloto solo es razonable si se aceptan explícitamente las restricciones y la contingencia.
2. Autorizar por separado la publicación del único índice; esperar READY.
3. Autorizar por separado publicar las reglas congeladas; repetir lectura de fuente/índices. No iniciar motores todavía. Verificar los módulos profesionales previos y Preview.
4. Elegir y autorizar un paciente/cuenta exclusivamente ficticios y sus actividades válidas existentes, profesional propietario, ventana de prueba y escrituras de prueba esperadas. No crear ni modificar pacientes/cuentas sin otra autorización. No editar/cancelar/eliminar actividades durante sesiones.
5. Autorizar aparte la activación Debug para `Medium_Phone_API_37.0`, nunca tablet ni release. Inicio del piloto: `USE_FIREBASE_EMULATORS=false`, `ENABLE_ACTIVITY_PREVIEW=false`, `ENABLE_ACTIVITY_EXECUTION=true`, `ENABLE_EXECUTION_HISTORY=false`, `ENABLE_EXECUTION_METRICS=false`. Este documento no ejecuta `flutter run` ni genera APK. Revisar el dispositivo seleccionado antes de cualquier lanzamiento futuro.
6. Probar un motor primero: inicio, bloqueo, reapertura, conflicto/cancelación, interrupción confirmada, finalización con un único resultado y ausencia de bloqueo. Luego repetir con los ocho. Simular pérdida de proceso y conexión de manera controlada. Detener ante errores inesperados, fuga de datos, duplicados o bloqueo incoherente; no repararlos improvisando.
7. Habilitar historial y métricas individualmente en Debug tras aprobación; confirmar propiedad profesional, página/índice READY y conteos de las sesiones piloto. Las lecturas ajenas deben fallar. La prueba real no autoriza cambios sobre información de pacientes reales.
8. Conservar evidencia mínima sin correos, UID, childId, tokens ni información clínica en logs compartidos. Cerrar explícitamente las sesiones piloto antes de apagar flags. Cualquier limpieza posterior de documentos necesita autorización separada.

## Recomendación

**Auditoría y preparación completadas; activación general condicionada.** No hay ampliación accidental de permisos previos ni fallo de unicidad del bloqueo en las pruebas. Se puede solicitar revisión/autorización del despliegue con estas limitaciones visibles, pero no presentar la habilitación funcional como libre de riesgos. Resolver el flujo de actividad ocultada o aceptar expresamente un piloto restringido antes de activar persistencia real.

Firebase real no fue modificado. Sin despliegue, sin activación, sin APK, sin Lenovo y sin FASE 11.
