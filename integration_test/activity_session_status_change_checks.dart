import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tea_app/core/firebase/firebase_bootstrap.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_execution_session_model.dart';
import 'package:tea_app/services/activity_execution_session_service.dart';
import 'package:tea_app/services/firestore_service.dart';

/// Exercises the real Dart service and native Android SDK, never production.
Future<void> verifyActivitySessionStatusChanges() async {
  if (!FirebaseBootstrap.useEmulators) {
    throw StateError('Status-change checks require demo-calmatea-local.');
  }
  if (Firebase.apps.isEmpty) await FirebaseBootstrap.initialize();
  if (Firebase.app().options.projectId != 'demo-calmatea-local') {
    throw StateError('Status-change checks require demo-calmatea-local.');
  }
  final child = await _LocalClient.open(
    'closing-child',
    'child@calmatea.test',
    proxied: true,
  );
  final professional = await _LocalClient.open(
    'closing-psych',
    'psychologist@calmatea.test',
  );
  final service = ActivityExecutionSessionService(
    auth: child.auth,
    firestoreService: FirestoreService(firestore: child.db),
  );
  final lock = child.db
      .collection('activeExecutionSessions')
      .doc('child-local-a');
  final permissionDenied = isA<FirebaseException>().having(
    (error) => error.code,
    'code',
    'permission-denied',
  );
  final metrics = <String, ActivityExecutionMetrics>{
    'sequence': SequenceExecutionMetrics(itemsCount: 2, checksCount: 1),
    'matching': MatchingExecutionMetrics(relationsCompleted: 2, checksCount: 1),
    'motor': MotorExecutionMetrics(stepsVisited: 2),
    'emotion': EmotionExecutionMetrics(exercisesReviewed: 2),
    'drag-drop': DragDropExecutionMetrics(itemsPlaced: 2, checksCount: 1),
    'pictogram': PictogramExecutionMetrics(interactionsCount: 2),
    'tracing': TracingExecutionMetrics(
      practiceCompleted: true,
      strokesCount: 1,
    ),
    'timer': TimerExecutionMetrics(
      configuredDurationSeconds: 5,
      elapsedSeconds: 5,
    ),
  };
  Future<DocumentReference<Map<String, dynamic>>> activityCopy(
    String engine,
    String suffix, {
    bool emptyConfiguration = false,
  }) async {
    final source = await professional.db
        .collection('activities')
        .doc('activity-$engine')
        .get(const GetOptions(source: Source.server));
    final data = source.data()!;
    final target = professional.db
        .collection('activities')
        .doc('closing-$engine-$suffix');
    await target.set({
      ...data,
      'status': 'assigned',
      if (emptyConfiguration) 'configuration': <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return target;
  }

  try {
    for (final status in ['completed', 'cancelled']) {
      for (final entry in metrics.entries) {
        debugPrint('Android closing regression: ${entry.key} after $status');
        final activity = await activityCopy(entry.key, status);
        final sessionId = await service.startSession(activityId: activity.id);
        await activity.update({'status': status});
        await expectLater(
          child.db
              .collection('activities')
              .doc(activity.id)
              .get(const GetOptions(source: Source.server)),
          throwsA(permissionDenied),
        );
        // Recovering the same ID is not creation of a new cancelled execution.
        expect(await service.startSession(activityId: activity.id), sessionId);
        await service.completeSession(
          sessionId: sessionId,
          metrics: entry.value,
        );
        final resultRef = child.db.collection('activityResults').doc(sessionId);
        final result = await resultRef.get(
          const GetOptions(source: Source.server),
        );
        await service.completeSession(
          sessionId: sessionId,
          metrics: entry.value,
        );
        expect(
          (await resultRef.get(const GetOptions(source: Source.server))).data(),
          result.data(),
        );
        expect(result.data()!['activityType'], entry.value.activityType.name);
        expect(
          (await service.getOwnSession(sessionId))!.status,
          ActivityExecutionSessionStatus.completed,
        );
        expect(
          (await lock.get(const GetOptions(source: Source.server))).exists,
          isFalse,
        );
        await expectLater(
          service.startSession(activityId: activity.id),
          // Native transactions can wrap the denied GET as unknown. The direct
          // GET above and Rules tests verify the actual authorization denial.
          throwsA(isA<FirebaseException>()),
        );
        expect(
          (await lock.get(const GetOptions(source: Source.server))).exists,
          isFalse,
        );
        await expectLater(
          resultRef.set(result.data()!),
          throwsA(permissionDenied),
        );
      }
      final activity = await activityCopy('sequence', 'interrupt-$status');
      final sessionId = await service.startSession(activityId: activity.id);
      await activity.update({'status': status});
      await service.interruptSession(sessionId);
      await service.interruptSession(sessionId);
      expect(
        (await service.getOwnSession(sessionId))!.status,
        ActivityExecutionSessionStatus.interrupted,
      );
      expect(
        (await lock.get(const GetOptions(source: Source.server))).exists,
        isFalse,
      );
    }

    for (final engine in metrics.keys) {
      final invalid = await activityCopy(
        engine,
        'unconfigured',
        emptyConfiguration: true,
      );
      await expectLater(
        service.startSession(activityId: invalid.id),
        // Native Firestore may wrap a transaction callback's StateError.
        throwsA(anyOf(isA<StateError>(), isA<FirebaseException>())),
      );
      expect(
        (await lock.get(const GetOptions(source: Source.server))).exists,
        isFalse,
      );
    }

    debugPrint(
      'Android closing regression: offline and retry without duplicates',
    );
    final activity = await activityCopy('sequence', 'network');
    final sessionId = await service.startSession(activityId: activity.id);
    await activity.update({'status': 'cancelled'});
    await _setTransactionTransport(online: false);
    final offlineAttempt = service.completeSession(
      sessionId: sessionId,
      metrics: metrics['sequence']!,
    );
    try {
      await offlineAttempt.timeout(const Duration(seconds: 8));
      fail('A Firestore transaction must not commit while offline.');
    } on FirebaseException {
      // No partial result is allowed. A subsequent retry uses the same session.
    } on TimeoutException {
      // The SDK may keep retrying until the connection returns.
    } finally {
      // The professional uses the direct emulator connection, so these checks
      // observe confirmed server state while the child's transport is cut.
      final current = await professional.db
          .collection('sessions')
          .doc(sessionId)
          .get(const GetOptions(source: Source.server));
      expect(current.data()!['status'], 'inProgress');
      final partialResults = await professional.db
          .collection('activityResults')
          .where(
            'psychologistId',
            isEqualTo: professional.auth.currentUser!.uid,
          )
          .where('id', isEqualTo: sessionId)
          .get(const GetOptions(source: Source.server));
      expect(partialResults.docs, isEmpty);
      await _setTransactionTransport(online: true);
    }
    await _completeAfterReconnect(service, sessionId, metrics['sequence']!);
    try {
      await offlineAttempt.timeout(const Duration(seconds: 40));
    } on FirebaseException {
      // The original offline transaction may have already failed.
    }
    await service.completeSession(
      sessionId: sessionId,
      metrics: metrics['sequence']!,
    );
    final result = await child.db
        .collection('activityResults')
        .doc(sessionId)
        .get(const GetOptions(source: Source.server));
    expect(result.exists, isTrue);
    expect(
      (await lock.get(const GetOptions(source: Source.server))).exists,
      isFalse,
    );

    // A late retry must leave the lock of a newer legitimate session untouched.
    final next = await activityCopy('sequence', 'new-lock');
    final nextSessionId = await service.startSession(activityId: next.id);
    await service.completeSession(
      sessionId: sessionId,
      metrics: metrics['sequence']!,
    );
    expect(
      (await lock.get(const GetOptions(source: Source.server)))
          .data()!['sessionId'],
      nextSessionId,
    );
    await service.interruptSession(nextSessionId);
  } finally {
    await _setTransactionTransport(online: true);
    await child.close();
    await professional.close();
  }
}

Future<void> _completeAfterReconnect(
  ActivityExecutionSessionService service,
  String sessionId,
  ActivityExecutionMetrics metrics,
) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    try {
      await service.completeSession(sessionId: sessionId, metrics: metrics);
      return;
    } on FirebaseException catch (error) {
      if (attempt == 9 ||
          ![
            'unavailable',
            'deadline-exceeded',
            'aborted',
          ].contains(error.code)) {
        rethrow;
      }
      debugPrint('Android closing regression: reconnect retry ${attempt + 1}');
      await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
    }
  }
}

Future<void> _setTransactionTransport({required bool online}) async {
  if (!FirebaseBootstrap.useEmulators ||
      Firebase.app().options.projectId != 'demo-calmatea-local') {
    throw StateError('The transaction transport gate is local-only.');
  }
  const port = int.fromEnvironment(
    'FIRESTORE_TEST_PROXY_CONTROL_PORT',
    defaultValue: 8091,
  );
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.postUrl(
      Uri(
        scheme: 'http',
        host: FirebaseBootstrap.emulatorHost,
        port: port,
        path: online ? '/resume' : '/pause',
      ),
    );
    final response = await request.close();
    await response.drain<void>();
    expect(response.statusCode, HttpStatus.noContent);
  } finally {
    client.close(force: true);
  }
}

class _LocalClient {
  final FirebaseApp app;
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  _LocalClient(this.app, this.auth, this.db);

  static Future<_LocalClient> open(
    String name,
    String email, {
    bool proxied = false,
  }) async {
    final options = Firebase.app().options;
    if (options.projectId != 'demo-calmatea-local')
      throw StateError('Non-demo project is forbidden.');
    final app = await Firebase.initializeApp(name: name, options: options);
    final auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator(
      FirebaseBootstrap.emulatorHost,
      FirebaseBootstrap.authEmulatorPort,
      automaticHostMapping: false,
    );
    final db = FirebaseFirestore.instanceFor(app: app);
    db.useFirestoreEmulator(
      FirebaseBootstrap.emulatorHost,
      proxied
          ? const int.fromEnvironment(
              'FIRESTORE_TEST_PROXY_PORT',
              defaultValue: 8090,
            )
          : FirebaseBootstrap.firestoreEmulatorPort,
      automaticHostMapping: false,
    );
    db.settings = const Settings(persistenceEnabled: false);
    await auth.signInWithEmailAndPassword(
      email: email,
      password: 'CalmaTEA-Local-Only-2026!',
    );
    return _LocalClient(app, auth, db);
  }

  Future<void> close() async {
    await db.enableNetwork();
    await auth.signOut();
    await db.terminate();
    await app.delete();
  }
}
