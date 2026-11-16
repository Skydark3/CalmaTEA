# FASE 10 — integridad de actividades

Fecha: 2026-10-31 (America/Bogota). Implementación y pruebas locales; producción sin escrituras.

## Diagnóstico

- `ActivityService.deleteActivity()` realizaba un borrado físico. No hay llamadas a este método en las pantallas ni botón de eliminación de actividad.
- `updateActivity()` enviaba un `type` nuevo sin comparar el persistido. EditActivityScreen solo bloqueaba el tipo cuando configuration no estaba vacía; un documento legacy con configuration vacía permitía cambiarlo.
- Las reglas publicadas permiten ambas operaciones al psicólogo propietario. Se comprobó mediante ADC y GET que siguen idénticas al respaldo original `tools/phase10-final-audit/published-2026-10-31/`; cero documentos de aplicación leídos y cero escrituras Firebase.
- Borrar una actividad invalida la comprobación interna del resultado y la lectura del historial; cambiar type invalida las métricas del motor en curso y puede invalidar resultados al reconstruir el historial con el tipo actual.
- `completeSession()` ya no relee actividades desde el cliente, pero las reglas conservan su comprobación interna de tipo y vínculos. La cancelación por sí sola no impide un cierre autorizado.

## Política mínima implementada

Todas las actividades persistidas son asignadas; no existe estado draft. Para evitar esquemas nuevos o comprobaciones check-then-delete con carreras, se prohíbe **todo borrado físico por clientes**, también de actividades que aún no tengan sesiones. Se retiran explícitamente mediante status cancelled. Es una restricción conservadora más fuerte que intentar permitir delete solo cuando no haya sesiones.

- `activities.type` es inmutable en cualquier actualización, incluso con configuración vacía o actividad ya cancelada.
- Las reglas deniegan delete sin consultas adicionales ni marcadores de uso.
- ActivityService rechaza cambiar el tipo y no lo envía como campo editable. La firma deleteActivity se conserva, pero lanza un error controlado sin borrar ni cancelar silenciosamente.
- La pantalla de edición mantiene el tipo bloqueado y explica cómo retirar mediante Cancelada. La inyección opcional de ActivityService permite probar el formulario sin inicializar Firebase; el comportamiento por defecto usa el mismo servicio.
- La creación sigue permitiendo seleccionar cualquiera de los ocho tipos **antes de guardar**. Para otro tipo después de asignar, crear una actividad nueva y cancelar la anterior si corresponde.
- No hay cambios de modelos, esquemas, ActivityStatus, sesiones, resultados ni configuraciones existentes. No se migraron documentos.

## Cambios y alcance exacto de reglas

En el bloque activities solamente:

```text
allow update: condiciones previas
              && request.resource.data.type == resource.data.type;

allow delete: if false;
```

Users, psychologists, children y therapies permanecen iguales a producción. Las reglas de sessions, activityResults y activeExecutionSessions permanecen iguales al candidato previo de FASE 10. No se amplió ningún permiso.

La cancelación conserva documento, ID, tipo y propietarios. Un niño no puede leer actividades canceladas ni iniciar nuevas sesiones mientras estén canceladas; la sesión ya autorizada puede completarse atómicamente. Los resultados siguen siendo inmutables y únicos por sessionId. El estado administrativo solo cambia por la operación explícita del profesional.

## Pruebas realmente ejecutadas

| Validación | Resultado |
| --- | --- |
| dart format en Dart modificado | Correcto |
| flutter analyze | Sin problemas |
| flutter test completo | 477/477 |
| Nuevos tests Dart incluidos | 20: ocho tipos, cancelación, no borrado, aislamiento del servicio y formulario configurado/legacy |
| Firestore Rules | 32/32 |
| Auditoría adicional | 5/5 |
| FASE 10 E2E | 12/12 suites; suite de bloqueo 17 casos |
| Advertencias de límite de expresiones/accesos documentales | Cero |

Firebase automatizado exclusivamente mediante `emulators:exec --only auth,firestore --project demo-calmatea-local`. En el E2E de cada uno de los ocho motores, con ambos estados terminales, se intentan borrar la actividad y cambiar type mientras la sesión está abierta; ambas operaciones son rechazadas. Después se cambia el estado, se completa, se reintenta, se comprueba un solo resultado y se vuelve a verificar que la actividad sigue existiendo con su tipo original. Los E2E existentes de historial, métricas y aislamiento también pasan.

No se ejecutó Android ni se generó APK en esta intervención, conforme a la restricción de no generar APK. El 2/2 Android anterior no se contabiliza como una ejecución nueva. El formulario actual tiene pruebas de widgets sin infraestructura Firebase.

## Archivos de aplicación y pruebas

- `firestore.rules`
- `lib/services/activity_service.dart`
- `lib/features/psychologist/activities/presentation/edit_activity_screen.dart`
- `test/activity_integrity_test.dart` (nuevo)
- `firestore-rules-test/rules.test.js`
- `firestore-rules-test/active-execution-session.e2e.test.js`

Además, este directorio contiene la comparación, herramienta de preparación y nuevo candidato congelado. Se añadió un aviso al informe previo para no publicar el candidato antiguo.

## Candidato y compatibilidad con producción

`node tools/phase10-activity-integrity/prepare-candidate.cjs` verifica los ocho hashes del respaldo publicado, comprueba que solo cambió el bloque activities respecto al candidato previo y materializa los artefactos locales. No contiene cliente Firebase ni acceso de red. Si el candidato cambia posteriormente, exige una nueva revisión en vez de sobrescribirlo.

Nuevo candidato: `candidate/firestore.rules`.

SHA-256: `5eb5bc27e86afb3d5509bd6d5ace1beacb1de0f8bf4106c3b558434a0afb089f`.

Índices sin cambios, SHA-256: `0851e25b02ee6d4084a3f0b2836e298bb96b3d3cd0ac8a877ab135b2a02480d7`. No hay nuevas consultas ni nuevos índices por estas protecciones. Sigue pendiente el índice de historial identificado anteriormente: sessions / psychologistId ASC, childId ASC, startedAt DESC.

**No usar el antiguo `tools/phase10-final-audit/deploy.rules.json`: apunta a un candidato que no contiene estas restricciones.** El respaldo publicado y las copias anteriores se conservaron sin sobrescribirlos. El comprobador anterior que exigía igualdad del bloque activities fallará ahora deliberadamente; la comparación válida de esta intervención está en `comparison.json`.

Las cuentas y documentos existentes son compatibles sin migración. Los clientes antiguos que intenten cambiar type o eliminar recibirán una denegación cuando se publiquen las reglas nuevas; el nuevo código evita ofrecer esa operación. No hay protección de backend en producción hasta un despliegue autorizado.

Comando futuro, preparado y **NO ejecutado**; exige autorización separada y nueva comprobación del estado publicado:

```powershell
firebase.cmd deploy --project calmatea-4c781 --config C:/TEA/tools/phase10-activity-integrity/deploy.rules.json --only firestore:rules
```

No ejecutar todavía. Publicar el índice y habilitar flags requieren sus propias autorizaciones. El despliegue de estas reglas debe formar parte del piloto controlado ya definido y no autoriza escribir sobre pacientes reales. La reversión al respaldo antiguo restauraría también sus permisos de borrado/cambio de tipo: revisar expresamente ese efecto en el plan de contingencia antes de publicar.

## Riesgos restantes y recomendación

- Firestore Rules no limitan operaciones administrativas realizadas mediante Admin SDK/IAM o consola con privilegios. No se modificó IAM ni se hicieron pruebas de escritura en producción.
- La política de eliminación de pacientes/terapias no cambia en esta tarea; requiere revisión propia antes de permitir eliminación de datos relacionados en un uso real.
- La configuración, título e instrucciones siguen siendo editables según las capacidades previas. No se añadió versionado/snapshot histórico de esos campos ni se alteraron resultados guardados.
- Datos ya borrados o reclasificados por medios previos/administrativos no se restauran ni migran automáticamente.

**Riesgos de borrado y cambio de tipo de actividades resueltos para clientes con las reglas propuestas. Aprobado localmente para solicitar revisión y autorización del candidato nuevo, no para desplegarlo sin autorización.** Conservar la política de cancelación, revisar los efectos de clientes antiguos y no habilitar persistencia real antes de publicar/validar reglas e índice con permiso explícito.

Sin cambios en Firebase real, sin despliegue, sin APK, sin Lenovo, sin Git y sin FASE 11.
