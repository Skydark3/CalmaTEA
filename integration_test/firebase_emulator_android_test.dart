import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tea_app/core/config/phase10_feature_flags.dart';
import 'package:tea_app/core/firebase/firebase_bootstrap.dart';
import 'package:tea_app/main.dart' as app;
import 'package:tea_app/models/activity_model.dart';

const _localPassword = 'CalmaTEA-Local-Only-2026!';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('recorre ambos roles y los ocho motores en Firebase Emulator', (
    tester,
  ) async {
    expect(FirebaseBootstrap.useEmulators, isTrue);
    expect(Phase10Features.activityExecutionEnabled, isTrue);
    expect(Phase10Features.executionHistoryEnabled, isTrue);
    expect(Phase10Features.executionMetricsEnabled, isTrue);

    await app.main();
    await FirebaseAuth.instance.signOut();
    await tester.pumpAndSettle();
    await _waitFor(tester, find.text('Comenzar'));
    final startButton = find.widgetWithText(ElevatedButton, 'Comenzar');
    await tester.ensureVisible(startButton);
    await tester.pump();
    await tester.tap(startButton);
    await tester.pumpAndSettle();
    await _waitFor(tester, find.byType(TextFormField));

    await _login(tester, 'child@calmatea.test');
    await _diagnoseProfileRead();
    await _waitFor(tester, find.text('Hola, Alex Prueba'));

    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Ir a mis actividades'),
    );
    await _waitFor(tester, find.text('Motor local'));

    debugPrint('Android validation step: motor');
    await _openActivity(tester, 'Motor local');
    expect(find.text('Paso 1 de 2'), findsOneWidget);
    await tester.tap(find.text('Siguiente paso'));
    await tester.pump();
    expect(find.text('Paso 2 de 2'), findsOneWidget);
    await tester.tap(find.text('Paso anterior'));
    await tester.pump();
    await _returnToActivities(tester);

    debugPrint('Android validation step: tracing');
    await _openActivity(tester, 'Tracing local');
    final canvas = find.byKey(const ValueKey('tracing-canvas'));
    await tester.ensureVisible(canvas);
    await tester.dragFrom(
      tester.getCenter(canvas) - const Offset(30, 20),
      const Offset(60, 40),
    );
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Deshacer'), 180);
    await tester.tap(find.text('Deshacer'));
    await tester.pump();
    await tester.ensureVisible(canvas);
    await tester.dragFrom(
      tester.getCenter(canvas) - const Offset(20, 10),
      const Offset(40, 20),
    );
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Limpiar'), 180);
    await tester.tap(find.text('Limpiar'));
    await tester.pump();
    await _returnToActivities(tester);

    debugPrint('Android validation step: timer');
    await _openActivity(tester, 'Timer local');
    await tester.tap(find.text('Iniciar'));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.tap(find.text('Pausar'));
    await tester.pump();
    await tester.tap(find.text('Continuar'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Reiniciar'));
    await tester.pump();
    expect(find.text('00:05'), findsOneWidget);
    await _returnToActivities(tester);

    debugPrint('Android validation step: dragDrop');
    await _openActivity(tester, 'Drag Drop local');
    await tester.tap(find.byKey(const ValueKey('drag-drop-item-apple')));
    await tester.tap(find.byKey(const ValueKey('drag-drop-target-fruits')));
    await tester.pump();
    final carrot = find.byKey(const ValueKey('drag-drop-item-carrot'));
    final vegetables = find.byKey(
      const ValueKey('drag-drop-target-vegetables'),
    );
    final gesture = await tester.startGesture(tester.getCenter(carrot));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(vegetables));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(find.text('2 de 2 elementos colocados'), findsOneWidget);
    await _returnToActivities(tester, waitForCompletion: true);

    debugPrint('Android validation step: pictogram');
    await _openActivity(tester, 'Pictogramas local');
    await tester.tap(
      find.byKey(const ValueKey('pictogram-option-pictogram-water')),
    );
    await tester.pump();
    expect(find.text('Has seleccionado: Agua'), findsOneWidget);
    await tester.tap(find.text('Limpiar selección'));
    await tester.pump();
    await _returnToActivities(tester);

    debugPrint('Android validation step: emotion');
    await _openActivity(tester, 'Emociones local');
    await tester.enterText(find.byType(TextField), 'alegria');
    await tester.tap(find.text('Revisar respuesta'));
    await tester.pump();
    await tester.tap(find.text('Siguiente'));
    await tester.pump();
    expect(find.text('Pregunta 2 de 2'), findsOneWidget);
    await _returnToActivities(tester);

    debugPrint('Android validation step: matching');
    await _openActivity(tester, 'Matching local');
    await tester.tap(find.text('Gato'));
    await tester.tap(find.text('Animal'));
    await tester.pump();
    expect(find.text('1 de 2 relaciones completadas'), findsOneWidget);
    await _returnToActivities(tester);

    debugPrint('Android validation step: sequence');
    await _openActivity(tester, 'Secuencia local');
    await tester.tap(find.byTooltip('Mover Guardar cuaderno hacia abajo'));
    await tester.pump();
    await tester.tap(find.text('Comprobar'));
    await tester.pump();
    await _waitFor(tester, find.text('¡Muy bien! Tu resultado fue guardado.'));
    await _returnToActivities(tester, waitForCompletion: true);

    debugPrint('Android validation step: child profile and logout');
    await tester.tap(find.text('Perfil'));
    await tester.pump();
    expect(find.text('Alex Prueba'), findsOneWidget);
    expect(find.text('child@calmatea.test'), findsOneWidget);
    expect(find.text('Paciente'), findsOneWidget);
    expect(find.text('child-local-a'), findsNothing);
    expect(find.textContaining('Nivel 1'), findsNothing);
    await tester.tap(find.text('Cerrar sesión'));
    await _waitFor(tester, find.byType(TextFormField));

    debugPrint('Android validation step: psychologist login');
    await _login(tester, 'psychologist@calmatea.test');
    await _waitFor(tester, find.textContaining('Hola, Psicologa'));
    final patientsTab = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Pacientes'),
    );
    await tester.tap(patientsTab);
    await _waitFor(tester, find.text('Alex Prueba'));
    expect(find.text('Paciente Local B'), findsOneWidget);

    debugPrint('Android validation step: professional activity creation');
    await _tapCardByText(tester, 'Alex Prueba');
    await _waitFor(tester, find.text('Detalle del paciente'));
    await _waitFor(tester, find.text('Terapia Ocupacional'));
    await _tapCardByText(tester, 'Terapia Ocupacional');
    await _waitFor(tester, find.text('Detalle de la terapia'));

    final createActivityButton = find.widgetWithText(
      OutlinedButton,
      'Crear actividad',
    );
    await tester.ensureVisible(createActivityButton);
    await tester.pumpAndSettle();
    await tester.tap(createActivityButton);
    await tester.pumpAndSettle();
    await _waitFor(tester, find.text('Crear actividad'));

    final activityFields = find.byType(TextFormField);
    await tester.enterText(activityFields.at(0), 'Temporizador UI local');
    await tester.enterText(activityFields.at(1), 'Creada desde Android');
    await tester.enterText(activityFields.at(2), '2');
    await tester.enterText(activityFields.at(3), 'Sigue el temporizador');
    await tester.tap(find.byType(DropdownButtonFormField<ActivityType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Temporizador').last);
    await tester.pumpAndSettle();

    final submitActivityButton = find.widgetWithText(
      ElevatedButton,
      'Configurar actividad',
    );
    await tester.ensureVisible(submitActivityButton);
    await tester.tap(submitActivityButton);
    await tester.pumpAndSettle();
    await _waitFor(tester, find.text('Configurar temporizador'));

    final minutesField = find.ancestor(
      of: find.text('Minutos'),
      matching: find.byType(TextFormField),
    );
    final secondsField = find.ancestor(
      of: find.text('Segundos'),
      matching: find.byType(TextFormField),
    );
    final timerLabelField = find.byType(TextFormField).last;
    await tester.enterText(minutesField, '0');
    await tester.enterText(secondsField, '10');
    await tester.enterText(timerLabelField, 'Validacion Android');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    final saveConfigurationButton = find.widgetWithText(
      ElevatedButton,
      'Validar configuración',
    );
    await _waitFor(tester, saveConfigurationButton);
    await tester.tap(saveConfigurationButton);
    await tester.pumpAndSettle();

    await _waitFor(tester, find.text('Temporizador UI local'));
    await _tapCardByText(tester, 'Temporizador UI local');
    await _waitFor(tester, find.text('Detalle de la actividad'));
    await tester.scrollUntilVisible(find.text('Temporizador configurado'), 350);
    await _waitFor(tester, find.text('Temporizador configurado'));
  });
}

Future<void> _tapCardByText(WidgetTester tester, String text) async {
  final textFinder = find.text(text);
  if (textFinder.hitTestable().evaluate().isEmpty) {
    final scrollable = find
        .ancestor(of: textFinder.first, matching: find.byType(Scrollable))
        .first;
    final delta = tester.getCenter(textFinder.first).dy < 0 ? -320.0 : 320.0;
    await tester.scrollUntilVisible(
      textFinder.first,
      delta,
      scrollable: scrollable,
    );
  }
  await tester.ensureVisible(textFinder.first);
  await tester.pumpAndSettle();
  final card = find
      .ancestor(of: textFinder.first, matching: find.byType(Card))
      .first;
  await tester.tap(card);
  await tester.pumpAndSettle();
}

Future<void> _diagnoseProfileRead() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    debugPrint('Android validation profile diagnostic: no authenticated user.');
    return;
  }

  try {
    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    debugPrint(
      'Android validation profile diagnostic: document exists=${profile.exists}.',
    );
  } on FirebaseException catch (error) {
    debugPrint(
      'Android validation profile diagnostic: Firestore code=${error.code}.',
    );
  } catch (error) {
    debugPrint('Android validation profile diagnostic: ${error.runtimeType}.');
  }
}

Future<void> _login(WidgetTester tester, String email) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), email);
  await tester.enterText(fields.at(1), _localPassword);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
  final loginButton = find.widgetWithText(ElevatedButton, 'Iniciar sesión');
  await tester.ensureVisible(loginButton);
  await tester.pump();
  await tester.tap(loginButton);
  await tester.pump();
  await _waitForAuthenticated(tester);
}

Future<void> _waitForAuthenticated(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (FirebaseAuth.instance.currentUser == null &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(FirebaseAuth.instance.currentUser, isNotNull);
}

Future<void> _openActivity(WidgetTester tester, String title) async {
  final titleFinder = find.text(title);
  if (titleFinder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(titleFinder, 260);
  } else {
    await tester.ensureVisible(titleFinder);
  }
  final card = find
      .ancestor(of: titleFinder, matching: find.byType(Card))
      .first;
  final startButton = find.descendant(
    of: card,
    matching: find.widgetWithText(ElevatedButton, 'Comenzar'),
  );
  await tester.tap(startButton);
  await tester.pumpAndSettle();
  expect(find.text(title), findsWidgets);
}

Future<void> _returnToActivities(
  WidgetTester tester, {
  bool waitForCompletion = false,
}) async {
  final returnButton = find.byKey(const ValueKey('activity-execution-return'));
  final activitiesTitle = find.text('Mis actividades');
  if (waitForCompletion) {
    await _waitFor(tester, returnButton);
  }

  final deadline = DateTime.now().add(const Duration(seconds: 20));
  var requestedSystemBack = false;
  while (activitiesTitle.evaluate().isEmpty &&
      DateTime.now().isBefore(deadline)) {
    final exitConfirmation = find.widgetWithText(FilledButton, 'Salir');
    if (exitConfirmation.evaluate().isNotEmpty) {
      await tester.tap(exitConfirmation);
      await tester.pump();
      continue;
    }

    if (returnButton.evaluate().isNotEmpty) {
      await tester.ensureVisible(returnButton.first);
      await tester.pump();
      final tappableReturnButton = returnButton.hitTestable();
      if (tappableReturnButton.evaluate().isEmpty) {
        await tester.pump(const Duration(milliseconds: 250));
        continue;
      }
      final button = tester.widget<ButtonStyleButton>(
        tappableReturnButton.first,
      );
      if (button.onPressed != null) {
        await tester.tap(tappableReturnButton.first);
        await tester.pump();
      } else {
        await tester.pump(const Duration(milliseconds: 250));
      }
      continue;
    }

    if (!requestedSystemBack) {
      requestedSystemBack = true;
      await tester.pageBack();
      await tester.pump();
      continue;
    }

    await tester.pump(const Duration(milliseconds: 250));
  }
  await _waitFor(tester, activitiesTitle);
}

Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  if (finder.evaluate().isEmpty) {
    final visibleTexts = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .where((text) => !text.contains(_localPassword))
        .join(' | ');
    debugPrint('Android validation visible text: $visibleTexts');
  }
  expect(finder, findsWidgets);
}
