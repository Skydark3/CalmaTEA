# FASE 10 — Preflight final sin despliegue

Fecha de revisión: 2026-11-01, America/Bogota.
Veredicto: **APTO para solicitar autorización separada de publicación controlada**.
No autoriza despliegue, activación funcional, escrituras de prueba ni publicación de APK.

## 1. Proyecto, base y publicación actual

Verificados mediante ADC normal y solicitudes GET a metadatos, sin consultar
documentos de aplicación. No se extrajeron credenciales internas de Firebase CLI.

- Proyecto: `calmatea-4c781`.
- Base: `projects/calmatea-4c781/databases/(default)`, FIRESTORE_NATIVE.
- Región: `southamerica-west1`.
- Lectura registrada: 2026-11-01 16:33:20 America/Bogota (21:33:20 UTC).
- Release: `projects/calmatea-4c781/releases/cloud.firestore`.
- Ruleset: `projects/calmatea-4c781/rulesets/e906613f-fbdc-43c0-abbc-d548cfeeac45`.
- Actualización publicada: `2026-10-08T18:50:32.162159Z`.
- La publicación fue estable entre las lecturas inicial/final.
- Fuente publicada, índices compuestos y política de índices de campo coinciden
  exactamente con el respaldo original. Actualmente no hay índices compuestos.
- Evidencia: `published-readonly.json`; cero documentos leídos y cero escrituras Firebase.

## 2. Congelación verificable

Copias byte a byte en este paquete; no se sobrescribió el respaldo original ni
se modificaron `firebase.json`, `.firebaserc`, reglas raíz, índices raíz o Flutter.
El manifiesto registra hashes, CLI, rutas, configuración y evidencia de pruebas.
La congelación es por hashes verificables, no una firma digital ni almacenamiento WORM.

| Artefacto | SHA-256 |
| --- | --- |
| backup/firestore.rules | d3d6661464da65f0101bbc1304e1c452527f57d59216be8ec4e52d8cfe77029e |
| candidate/firestore.rules | 5eb5bc27e86afb3d5509bd6d5ace1beacb1de0f8bf4106c3b558434a0afb089f |
| candidate/firestore.indexes.json | 0851e25b02ee6d4084a3f0b2836e298bb96b3d3cd0ac8a877ab135b2a02480d7 |

Los ocho archivos del manifiesto original del respaldo fueron verificados y
copiados junto con su manifiesto. La copia de reglas también coincide con el
contenido extraído del ruleset publicado. No es un respaldo de documentos.

El candidato coincide con las reglas raíz y con
`tools/phase10-activity-integrity/candidate/firestore.rules`.
NO es el candidato histórico `tools/phase10-final-audit/proposed-2026-10-31/`,
cuyo hash de reglas es distinto y no incorpora la corrección de integridad final.

## 3. Configuración exacta de Firebase CLI

Sin `--config`, `C:/TEA/firebase.json` selecciona:

- `C:/TEA/firestore.rules` y `C:/TEA/firestore.indexes.json`.
- Base `(default)` implícita.
- `.firebaserc`: alias default `calmatea-4c781`, sin targets adicionales.
- Functions tiene hooks predeploy `npm ... run lint` y `npm ... run build`.
  No hay hooks Firestore ni postdeploy. No usar un `firebase deploy` genérico.

Para eliminar ambigüedad se prepararon configuraciones nuevas SOLO locales:

| Configuración dentro de este paquete | Destino exacto | Selector autorizado a proponer |
| --- | --- | --- |
| firebase.indexes.json | `(default)` / candidate/firestore.indexes.json | firestore:indexes |
| firebase.rules.json | `(default)` / candidate/firestore.rules | firestore:rules |
| firebase.rollback.json | `(default)` / backup/firestore.rules | firestore:rules |

Todas contienen únicamente `firestore`, base explícita, sin hooks ni Functions.
Las rutas son relativas al directorio de `--config`, comportamiento confirmado
con el código instalado de Firebase CLI y su resolver puro de configuración.
NO se invocaron `deploy`, `prepare`, compilación remota ni publicación de rulesets.

No existía `C:/TEA/firebase.rollback.json`. Se creó el archivo solicitado dentro
de ESTE paquete; el archivo histórico `tools/phase10-final-audit/rollback.rules.json`
permanece intacto. Los comandos de esta revisión usan exclusivamente el paquete nuevo.

## 4. Diff final y seguridad

Diff íntegro: `rules.published-to-final.diff`.

- `users`, `psychologists`, `children` y `therapies`: bloques idénticos byte a byte.
- `activities`: únicamente añade igualdad del tipo durante update y deniega todo
  borrado físico por clientes. Create/read y sus validaciones permanecen iguales.
  Update conserva `cancelled` y el ownership previo. No se amplían lecturas infantiles.
- `sessions`: sustituye la denegación publicada por inicio/cierre autorizados,
  identidad vinculada, propiedades inmutables, timestamps del servidor, resultado
  obligatorio al completar y eliminación atómica del bloqueo correspondiente.
- `activityResults`: resultado único por sessionId, esquema/métricas permitidas,
  sesión que pasa de inProgress a completed en la misma operación, coincidencia de
  actividad/tipo/vínculos, sin update/delete. Lectura solo del niño propietario o
  psicólogo propietario. No se requiere que la actividad siga assigned al cerrar.
- `activeExecutionSessions`: bloqueo por childId; creación vinculada a sesión
  inProgress y startedAt=request.time. Get solo del niño vinculado, list/update
  denegados. Delete requiere propietario y que SU sesión esté cerrada o cierre
  atómicamente. La primera sesión mantiene el bloqueo; otro dispositivo no lo actualiza.
- Los nuevos helpers se usan para FASE 10; las demás reglas y la denegación por
  defecto no cambian. La proyección automática del diff confirma ese alcance exacto.

## 5. Índice y consulta de historial

Único índice propuesto: colección `sessions`, alcance COLLECTION:

`psychologistId ASC, childId ASC, startedAt DESC`.

No hay fieldOverrides ni índices de otras colecciones.
`PatientActivityHistoryService` consulta psychologistId==uid y childId==paciente,
ordena startedAt descendente, limita a 20 y pagina con startAfterDocument.
Ese índice cubre la consulta. El emulador no certifica su construcción en producción.

## 6. Pruebas y flags

Se revisaron y se fijaron por hash los logs finales existentes, NO se repitieron
Flutter, Rules, E2E o Android en este preflight:

- Analyze sin problemas; Flutter 480/480; Rules 32/32.
- FASE 10 E2E: 12/12 suites, incluidas concurrencia, aislamiento e integridad.
- Android: dos repeticiones consecutivas 2/2 tras la corrección transaccional.
- Los registros preservan también la ejecución intermedia fallida; no se ocultó.
- Revisión anterior de logs: cero advertencias de límites de expresiones/accesos.
- Los verificadores NUEVOS se probaron hoy con metadatos ficticios sin ADC/red:
  `node --test tools/phase10-preflight-2026-11-01/read-published.test.cjs` → 10/10.
  Rechazan proyecto incorrecto, cambio concurrente de release, índice ausente,
  CREATING, índices extra y fuente publicada incorrecta. Aceptan rollback con un
  ruleset ID nuevo siempre que el contenido sea exactamente el respaldo.

ENABLE_ACTIVITY_EXECUTION, ENABLE_EXECUTION_HISTORY y ENABLE_EXECUTION_METRICS
siguen false por defecto; Preview también false por defecto. Solo dart-define
explícito habilita funciones Debug; release las bloquea. AuthGate usa los defaults
del shell, sin activar un router persistente por la selección de Firebase.

IMPORTANTE: esto confirma el código/defaults, NO los flags de cualquier APK ya
instalado. Los últimos recorridos Android habilitaron ejecución/historial/métricas
contra demo-calmatea-local deliberadamente. No son una compilación para producción.
No se inspeccionó ni generó un APK, ni se activaron flags en esta intervención.

## 7. Firebase CLI empleada

- Firebase CLI 15.32.1; Node v22.19.0.
- Launcher: `C:/Users/ALEJANDRO/AppData/Roaming/npm/firebase.cmd`.
- SHA-256 launcher: `31747b4cbfe19fd8e36bb630841942ae1777dd95adc6362151d178c7470e322e`.
- Entrada `lib/bin/firebase.js`:
  `1e05ff8373e5a5c7222475a0d90d4db58c85c2f281d44d4884bc96062288b864`.
- Árbol lib + package.json (885 archivos, algoritmo documentado en manifest):
  `0b9b7aa642661ceaeae23550a21cf22bed5f510a91534072f7e2eccced4d50dc`.
- Hashes de package.json y node.exe también se registran en manifest.
  La huella de lib NO incluye el árbol de dependencias node_modules.
- `--version` requirió el acceso normal a su configuración de usuario; no se leyó
  ni imprimió el contenido de esa configuración. Las lecturas Google usaron ADC.

## 8. Comandos PROPUESTOS: no ejecutados

Ejecutar en PowerShell desde `C:/TEA`, SOLO tras autorización nueva explícita.
No actualizar CLI, editar el manifiesto ni regenerar las copias para hacer pasar
una comprobación fallida. Cualquier drift exige revisión nueva.

Primero, comprobaciones locales y remotas sin escrituras:

```powershell
node .\tools\phase10-preflight-2026-11-01\verify-local.cjs
node .\tools\phase10-preflight-2026-11-01\read-published.cjs --preflight
```

### A. Publicar únicamente el índice aprobado

```powershell
firebase.cmd deploy --project calmatea-4c781 --config C:/TEA/tools/phase10-preflight-2026-11-01/firebase.indexes.json --only firestore:indexes --non-interactive
```

No usar `--force`; no aceptar eliminación de índices/field overrides adicionales.
Aunque el comando termine, eso NO garantiza READY.

### B. Comprobar READY mediante GET

```powershell
node .\tools\phase10-preflight-2026-11-01\verify-local.cjs
node .\tools\phase10-preflight-2026-11-01\read-published.cjs --ready
```

Exige el índice exacto, state READY, política de campo sin cambios y las reglas
antiguas aún publicadas. GET paginado:
`https://firestore.googleapis.com/v1/projects/calmatea-4c781/databases/(default)/collectionGroups/-/indexes`.
Si está ausente o CREATING, esperar y repetir solo esa lectura; si NEEDS_REPAIR,
hay índices extra o cambió la publicación, detenerse. No continuar con exit code != 0.

### C. Publicar únicamente las reglas finales

```powershell
firebase.cmd deploy --project calmatea-4c781 --config C:/TEA/tools/phase10-preflight-2026-11-01/firebase.rules.json --only firestore:rules --non-interactive
```

### D. Verificación posterior sin datos de aplicación

```powershell
node .\tools\phase10-preflight-2026-11-01\verify-local.cjs
node .\tools\phase10-preflight-2026-11-01\read-published.cjs --candidate
```

Relee proyecto/base, release y ruleset, exige SHA final, índice READY exacto y
política de campo original. El ID del nuevo ruleset se obtiene de la publicación;
no se adivina. La verificación hace dos lecturas de release para detectar carreras.
Las pruebas reales que escriban sesiones/resultados necesitan autorización aparte.
No activar persistencia ni reconstruir/distribuir la app como efecto del deploy.

## 9. Reversión propuesta sin borrar datos

También requiere autorización de publicación. Detener primero nuevos inicios
persistentes; si es posible, cerrar las sesiones controladas aún abiertas antes
de revocar sus permisos. Si es urgente revocar, conservar sus documentos/bloqueos
para revisión posterior: no ejecutar limpiezas o cierres administrativos masivos.

```powershell
node .\tools\phase10-preflight-2026-11-01\verify-local.cjs
firebase.cmd deploy --project calmatea-4c781 --config C:/TEA/tools/phase10-preflight-2026-11-01/firebase.rollback.json --only firestore:rules --non-interactive
node .\tools\phase10-preflight-2026-11-01\read-published.cjs --rollback
```

Publica exactamente backup/firestore.rules. No incorpora índices, Functions,
otros servicios, borrado de datos ni eliminación del índice aditivo aprobado.
Un rollback puede crear otro ruleset ID; se verifica el SHA del contenido.

ADVERTENCIA: el respaldo restaura los permisos antiguos de activities (permitían
cambiar tipo y borrar físicamente), y vuelve a denegar FASE 10. No es un candidato
endurecido alternativo. Sesiones/resultados permanecen guardados, pero sus clientes
perderán acceso hasta una publicación posterior revisada. Valorar expresamente
este intercambio de seguridad al autorizar una reversión.

## 10. Riesgos y condición de aprobación

- APTO para solicitar autorización de backend: fuente exacta, respaldo, diff,
  herramientas y comandos acotados identificados; ninguna modificación remota.
- El índice todavía no existe: no publicar reglas hasta comprobar READY.
- Deben repetirse las comprobaciones de drift inmediatamente antes de publicar;
  permisos ADC de lectura no certifican IAM de despliegue ni el login futuro de CLI.
- La reversión es de reglas, no de documentos. No se respaldaron datos clínicos,
  y no se afirma una restauración de datos que este procedimiento no realiza.
- Las pruebas locales no certifican cuotas, latencia, propagación ni redes reales.
  Persisten las advertencias de herramientas documentadas en la validación Android.
- Los flags no son controles de autorización. Su activación real y toda escritura
  funcional necesitan otra autorización, con prueba gradual y datos autorizados.
- No se pueden afirmar los flags de un APK instalado a partir de los defaults.
- Huella de CLI sin dependencias transitivas: si cambia la instalación, renovar
  revisión. No usar configs históricas ni deploy genérico.
- No se modificaron producción, usuarios, pacientes, terapias, actividades, Git,
  código Flutter ni release. No se generó APK y no se inició FASE 11.
