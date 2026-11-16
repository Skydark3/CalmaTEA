# FASE 10 — Validación Android final previa al despliegue

Fecha: 2026-10-31. Proyecto local: C:/TEA. AVD: Medium_Phone_API_37.0,
serial emulator-5554, 1080 × 2400 px, densidad 420 (~411 dp).

## Aislamiento

Todas las pruebas Firebase utilizaron demo-calmatea-local, Auth 127.0.0.1:9099
y Firestore 127.0.0.1:8080 (10.0.2.2 desde Android). No se consultó ni modificó
Firebase real en esta intervención. No hubo despliegues, cambios Git, uso de
Lenovo ni APK entregable. Flutter run/test produjo únicamente los artefactos
temporales necesarios para ejecutar las pruebas en el emulador.

## Resultados ejecutados

| Validación | Resultado | Evidencia |
| --- | --- | --- |
| flutter analyze final | Sin problemas | flutter-analyze.log |
| flutter test final completo | 480/480 | flutter-test-final.log |
| Firestore Rules | 32/32 | rules-test.log |
| FASE 10 E2E | 12/12 suites, incluyendo 17 casos de bloqueo/cierre | phase10-e2e-final.log |
| Android integral inicial | 2/2 | C:/TEA/android-final-validation.log |
| Android después del arreglo visual, antes del arreglo transaccional | 1 aprobada, 1 fallida en reconexión | android-integral-after-fix.log |
| Android después del arreglo transaccional | 2/2 | android-integral-transaction-fix.log |
| Segunda repetición Android después del arreglo transaccional | 2/2 | android-integral-confirmation.log |

Los tests completos no fueron reducidos ni eliminados. El incremento de 477 a
480 corresponde a tres regresiones nuevas del manejo de errores transaccionales.
Las pruebas de edición existentes también comprueban ahora las líneas de ayuda.

## Alcance Android integral real

El test UI existente recorre los ocho motores con fixtures ya configurados:

- Motor: siguiente paso y paso anterior.
- Tracing: dibujar, deshacer y limpiar.
- Timer: iniciar, pausar, continuar y reiniciar.
- DragDrop: selección táctil y arrastre hasta completar los dos elementos.
- Pictogram: seleccionar y limpiar.
- Emotion: revisar respuesta y pasar al segundo ejercicio.
- Matching: completar una relación.
- Sequence: comprobar orden y confirmar resultado guardado.

También prueba login/logout infantil, privacidad del perfil, login profesional,
pacientes, terapia y creación/configuración/asignación de un temporizador nuevo.
No equivale a crear manualmente los ocho tipos desde sus ocho formularios en
Android; esos configuradores/flujos están cubiertos por la suite Flutter.

El segundo test Android usa el servicio Dart real para finalizar los ocho tipos
tras completed y cancelled (16 combinaciones), interrumpir, recuperar la misma
sesión, rechazar configuración vacía, impedir nuevas ejecuciones canceladas y
rechazar cambios de tipo/borrado. Verifica resultado único y bloqueo liberado.
Corta físicamente TCP mediante el proxy local 8090/8091; comprueba estado servidor
sin resultado parcial y reintenta después de reconectar. Un reintento antiguo no
puede liberar el bloqueo de una sesión posterior.

## Comprobaciones Android manuales adicionales

- Profesional autenticado: PATCH de cambio de tipo y DELETE de la actividad
  local devolvieron HTTP 403. La lectura posterior confirmó documento y tipo
  conservados. No existe botón UI de borrado de actividad que se haya probado.
- Tipo deshabilitado en edición; Cancelada se pudo guardar y volvió al detalle
  con mensaje de actualización correcta. El temporizador cancelado desapareció
  de las actividades disponibles del niño.
- Force-stop real del proceso y reapertura de Motor: mismo sessionId y mismo
  bloqueo confirmados mediante lectura del servidor local.
- Tras otro force-stop, intentar Tracing mostró «Actividad en curso» con
  Cancelar/Interrumpir y continuar. Cancelar conservó el bloqueo original.
- Finalizar Motor recuperado dejó exactamente una sesión completed, un resultado
  y ningún bloqueo. Dashboard: registradas 1, completadas 1, interrumpidas 0,
  sin cierre 0. Historial y detalle mostraron el mismo Motor y sus pasos visitados.
- Preview: finalización Motor, dibujo Tracing, botón Atrás y salida confirmada.
  Conteos antes/después: sessions=0, activityResults=0,
  activeExecutionSessions=0. La tarjeta identificó el modo sin guardar resultados.
  Las ocho persistencias efímeras y el router se verificaron además en Flutter;
  no se afirma un recorrido manual Android completo de los ocho en Preview.

Capturas 02/05 comparan la edición antes/después; 06 muestra Motor finalizado
tras reinicio; 07/08 muestran Dashboard/historial; 09 muestra Motor Preview.
Las capturas contienen exclusivamente fixtures ficticios locales.

## Defectos y correcciones mínimas

1. Aviso «Selecciona Cancelada para retirarla sin borrar su historial» truncado
   con puntos suspensivos en Android. Se permiten tres líneas en los dos avisos
   de integridad. Verificado visualmente sin modificar estilos generales.
2. Una repetición del corte/reconexión produjo FirebaseException
   cloud_firestore/unknown y abortó la prueba. El servidor mantuvo sesión y
   bloqueo inProgress, sin resultado parcial. El servicio conserva ahora la
   excepción del callback cuando el puente nativo la sustituye por unknown.
   No interpreta unknown como éxito, no reintenta automáticamente y no oculta
   errores nativos sin una causa capturada. Se conservan autorización, sesión,
   resultado determinista y transacción originales. Regresiones nuevas:
   unavailable enmascarado, permission-denied enmascarado y unknown sin causa.
   Dos repeticiones Android consecutivas posteriores aprobaron 2/2, incluyendo
   el reintento existente tras el corte TCP. Se conserva también el log fallido.

Archivos de código modificados en esta intervención:

- lib/features/psychologist/activities/presentation/edit_activity_screen.dart
- lib/services/activity_execution_session_service.dart
- test/activity_integrity_test.dart
- test/activity_execution_status_change_test.dart

No se modificaron modelos, motores, configuraciones, flags, reglas ni índices.

## Candidato de reglas e índice

El candidato vigente es tools/phase10-activity-integrity/candidate/firestore.rules,
idéntico al firestore.rules raíz (SHA-256):

5eb5bc27e86afb3d5509bd6d5ace1beacb1de0f8bf4106c3b558434a0afb089f

Incluye activities.type inmutable y delete denegado; cancelación explícita;
sesiones y resultados con propietarios/vínculos inmutables; resultado único e
inmutable; cierre atómico; activeExecutionSessions con create vinculado a sesión,
get solo del niño vinculado, list/update denegados y delete condicionado al
cierre de su sesión. Las pruebas negativas verifican aislamiento.

firestore.indexes.json y el candidato declaran el índice COLLECTION de sessions:
psychologistId ASC, childId ASC, startedAt DESC. Coincide con la consulta paginada
del historial. SHA-256:

0851e25b02ee6d4084a3f0b2836e298bb96b3d3cd0ac8a877ab135b2a02480d7

No surgieron consultas ni índices nuevos por las correcciones de esta validación.
El emulador no certifica que ese índice esté construido en producción.
No se reconsultó la configuración publicada durante esta intervención.

## Límites y advertencias

No aparecieron advertencias de límite de expresiones/accesos en los logs de
Firestore revisados. PERMISSION_DENIED y evaluation error en pruebas negativas
son denegaciones esperadas, no advertencias de 1000 expresiones.

Se observaron advertencias Java/native-access, futura compatibilidad Kotlin de
plugins y fotogramas omitidos en Debug. Una ejecución prolongada de Preview
registró GOAWAY/too_many_pings del emulador; la comprobación funcional y los
conteos servidor concluyeron correctamente. No se certifica rendimiento release,
otro tamaño de pantalla, hardware físico ni una red de producción.

El resultado local permite revisar una autorización separada de despliegue
controlado, nunca una activación automática. Antes de habilitar persistencia real
se deben publicar por separado el candidato revisado y el índice, esperar índice
listo y aplicar el plan de respaldo/reversión previamente auditado. Mantener flags
de producción desactivados hasta una autorización expresa. No se publicó nada.
