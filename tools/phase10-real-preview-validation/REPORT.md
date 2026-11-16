# FASE 10 — Validación funcional Preview: avance y punto de pausa

Proyecto: C:\TEA. Las pruebas Flutter/instalación se realizaron el 2026-11-01; la validación de sesión profesional y las actividades existentes se completó el 2026-11-03.

## 1. Versión y flags del emulador

- Iniciado y verificado `Medium_Phone_API_37.0`, dispositivo `emulator-5554`.
- La instalación anterior informaba versión 1.0.0 (1). Ese número no identifica su fuente ni sus dart-defines; no se atribuye el problema a una versión antigua sin evidencia.
- Ejecutado correctamente Flutter Debug desde `lib/main.dart`, conservando datos, sin desinstalar y sin crear un APK entregable:

```powershell
flutter run -d emulator-5554 --debug --no-resident --dart-define=USE_FIREBASE_EMULATORS=false --dart-define=ENABLE_ACTIVITY_PREVIEW=true --dart-define=ENABLE_ACTIVITY_EXECUTION=false --dart-define=ENABLE_EXECUTION_HISTORY=false --dart-define=ENABLE_EXECUTION_METRICS=false
```

- El artefacto intermedio de Flutter y el APK instalado coinciden por SHA-256:
  `a3fd402728e1f8e70b7fd0634a3b87647df8c642150dd88dc7dce233c1b03fba`.
- Package: `com.calmatea.app`; versión 1.0.0 (1); minSdk 24; targetSdk 36.
- Se verificó MainActivity en primer plano. No se certifica todavía el recorrido autenticado.

## 2. Proyecto Firebase

- FirebaseOptions Android y google-services.json apuntan a `calmatea-4c781` y al package indicado.
- Con `USE_FIREBASE_EMULATORS=false`, FirebaseBootstrap retorna antes de llamar a useAuthEmulator/useFirestoreEmulator.
- No hay redirecciones ADB; esta ejecución no depende de localhost ni 10.0.2.2.
- Confirmada la configuración de compilación; pendiente demostrar lecturas autenticadas desde el servidor real mediante login manual.
- No se usaron ADC, Admin SDK ni credenciales del proyecto demo para consultar documentos reales.

## 3. Autenticación profesional

- Login manual con la cuenta existente y dashboard profesional confirmados en la interfaz.
- Navegación al paciente ficticio previamente autorizado y a sus dos terapias completada.
- Sesión profesional cerrada desde Perfil de la app al preparar el paso infantil.
- No se solicitaron contraseñas por chat ni se introdujeron credenciales automáticamente.

## 4. Autenticación infantil

Pendiente del inicio de sesión manual con la cuenta infantil existente, después de la revisión profesional. AuthGate y ChildActivityService siguen exigiendo rol child y vínculo childId válido.

## 5. Actividades existentes configuradas

En la interfaz profesional se revisaron dos terapias del paciente ficticio autorizado. Se observaron siete actividades. Los tipos y estados visibles son:

| Tipo | Estado | Preparación observada |
| --- | --- | --- |
| Trazado | Asignada | Sin aviso de configuración pendiente; candidata configurada |
| Emociones | Asignada | Sin aviso de configuración pendiente; candidata configurada |
| Emparejamiento | En progreso | Sin aviso de configuración pendiente; candidata configurada |
| Motor | En progreso | Sin aviso de configuración pendiente; candidata configurada |
| Arrastrar y soltar | Completada | No ejecutable por estado |
| Emparejamiento | Cancelada | No ejecutable por estado; además muestra pendiente de configuración |
| Motor | Asignada | Pendiente; el detalle confirmó configuration vacía/no interactiva |

La lectura es de la UI autenticada, sin imprimir títulos, nombres, IDs, notas, configuraciones ni datos clínicos. La interfaz profesional identifica como configuradas las cuatro candidatas (no muestra badge de pendiente/inválida). Su ejecución infantil aún no se ha probado en esta sesión.

## 6. Actividades existentes bloqueadas

- Una actividad Motor asignada: causa confirmada, configuración vacía/no interactiva; requiere configuración por el profesional para ser ejecutable. No se modificó.
- Una actividad Emparejamiento cancelada: el flujo infantil la excluye por estado; la tarjeta profesional también muestra pendiente de configuración, pero no se abrió su detalle y por tanto no se afirma si además está vacía o inválida.
- Una actividad Arrastrar y soltar completada: excluida de la lista infantil por estado. No es un fallo de permisos/router y no se reactivó.
- No se observó un error permission-denied, conectividad o navegación durante la carga profesional. Esto no descarta errores en la consulta infantil, aún pendiente.

## 7. Diagnóstico de mensajes

Según ActivityExecutionRouter y ChildActivitiesScreen:

| Situación | Resultado |
| --- | --- |
| configuration vacía | unconfigured; pendiente de preparación; no se abre |
| configuration malformada o inválida para su tipo | invalidConfiguration; pendiente de preparación; no se abre |
| estado distinto de assigned/inProgress | blockedStatus; no disponible |
| configuración válida pero sin handler habilitado | engineUnavailable; disponible próximamente |
| configuración válida y handler Preview habilitado | ready; Probar actividad |
| error del stream de lectura | No pudimos cargar tus actividades |

Son condiciones comprobadas del código, no causas confirmadas de documentos particulares. Un mensaje de configuración pendiente no demuestra permission-denied.

## 8. Ocho motores

Sequence, Matching, Motor, Emotion, DragDrop, Pictogram, Tracing y Timer cuentan con factory, configurador y handler Preview. Pruebas locales de resolución, configuraciones válidas y apertura infantil aprobadas. No se ejecutaron los ocho motores con cuentas reales en esta intervención.

## 9. Creación y asignación

- El borrador se configura en memoria con `persistChanges: false`.
- La UI valida la configuración antes de invocar ActivityService.createActivity; el servicio también la valida.
- Cancelar el configurador no crea documentos.
- El reintento de guardado conserva el ID del borrador: no genera un ID distinto. Esto no certifica por sí solo todos los casos de respuesta de red ambigua contra las reglas desplegadas.
- ActivityStatus conserva assigned/inProgress/completed/cancelled. El estado de configuración es independiente y no agrega estados persistidos.
- Los configuradores de actividades existentes actualizan el mismo documento; no se ejecutó ninguna actualización real.
- El flujo de creación se comprobó con dobles locales, no creando pacientes, terapias ni actividades en producción.

## 10. Preview

- Los ocho handlers inyectan implementaciones de persistencia efímera.
- start/complete/interrupt/getSession/getResult de Preview no llaman Firebase.
- ChildActivitiesScreen omite el coordinador transaccional cuando el modo no es persistent.
- Prueba específica aprobada: Preview abre sin adquirir ni liberar bloqueos.
- No se modificaron controladores, servicios persistentes ni componentes visuales.

## 11. Conectividad

- AuthGate tiene timeout de 20 segundos y reintento para unavailable; ambos comportamientos pasaron las pruebas locales.
- ChildActivityService consulta por childId y status assigned/inProgress, sin consulta global. Las excepciones no se convierten en lista vacía.
- La consulta es compatible por inspección con el respaldo de reglas publicado previamente verificado; no se volvió a consultar la configuración de producción en esta tarea.
- Las lecturas usan la política normal del SDK y el stream no expone metadata de caché/servidor a la UI. Ver datos visibles no basta para certificar una lectura fresca del servidor.
- No se reprodujo pérdida/reconexión en una sesión real.
- La muestra de logs del proceso actual no contenía los códigos buscados: cloud_firestore/unavailable, permission-denied, invalid-credential, network-request-failed, LateInitializationError ni FATAL EXCEPTION. Ausencia en esa muestra no demuestra ausencia de errores en todo el recorrido.
- Se filtraron logs por códigos permitidos; no se guardaron logs brutos, capturas de credenciales ni volcados de datos clínicos.
- El intento de inspección de etiquetas mediante UI Automator no devolvió XML utilizable; no se presenta como evidencia visual de login.

## 12. Archivos modificados

Ningún archivo fuente Flutter, regla, índice ni configuración de Firebase modificado. Se añadió únicamente este informe. Flutter actualizó sus artefactos generados de compilación locales.

El verificador offline del paquete `tools/phase10-preflight-2026-11-01` terminó correctamente: paquete congelado preservado.

## 13. Flutter analyze

Ejecutado en esta intervención: **sin problemas**, exit code 0.

## 14. Flutter test

- Suite completa ejecutada: **480/480**, exit code 0.
- Reejecución focalizada: **57/57**, exit code 0, sobre:
  - create_activity_flow_test.dart
  - activity_configuration_routing_test.dart
  - activity_configuration_test.dart
  - activity_execution_router_test.dart
  - activity_preview_persistence_test.dart
  - auth_gate_profile_resolver_test.dart
  - features/child/child_shell_test.dart
  - features/child/child_activities_transactional_lock_test.dart
- Firestore Rules y E2E Firebase no se reejecutaron en esta tarea; no se cuentan los resultados históricos como nuevos.
- Dos lanzamientos iniciales restringidos quedaron bloqueados y fueron terminados; los resultados anteriores corresponden a las ejecuciones posteriores autorizadas que finalizaron realmente.

## 15. Android

Compilación, instalación conservando datos, verificación SHA-256 y arranque correctos. El 2026-11-03 se confirmó el dashboard profesional, navegación a dos terapias, lectura de siete actividades y logout normal. La app está ahora en la pantalla pública de login. No es un Android E2E completo: falta el login infantil y probar la apertura de las actividades desde esa sesión.

## 16. Cambios en Firebase real

Ninguna operación de escritura, creación de cuenta o modificación de documentos ejecutada por esta intervención. Sin despliegues, sin persistencia FASE 10, sin cambio de reglas/índices. No se usó la tablet ni Git.

## 17. Próximas acciones autorizables

1. La revisión profesional y el cierre de sesión ya se completaron.
2. Falta que el usuario inicie manualmente la cuenta infantil existente vinculada y confirme que la app muestra “Mis actividades”. No se solicitaron credenciales.
3. Probar las candidatas ya configuradas en Preview, observar navegación y errores. No se ha hecho todavía.
4. Para la actividad incompleta, presentar la corrección concreta y esperar autorización antes de guardar cambios.
5. No hay en las dos terapias inspeccionadas actividades asignadas de Sequence, Pictogram o Timer; no se inventarán datos para cubrir esos motores.

## 18. Estado final de este avance

**Preparación y validación local correctas. Login profesional y lectura de actividades existentes completados sin escrituras. La ejecución infantil real en Preview sigue pendiente del login manual child. FASE 10 no se declara cerrada.**

No se despliega ni se habilita persistencia como parte de este trabajo.
