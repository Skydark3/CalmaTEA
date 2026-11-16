import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tea_app/models/activity_execution_result_model.dart';
import 'package:tea_app/models/activity_model.dart';
import 'package:tea_app/services/activity_execution_session_service.dart';
import 'package:tea_app/services/firestore_service.dart';

void main() {
  for (final status in ['completed', 'cancelled']) {
    for (final type in ActivityType.values) {
      test('${type.name}: cierra tras $status sin leer activities', () async {
        final db = _MemoryFirestore(type);
        final service = _service(db);
        db.activityStatus = status;
        await service.completeSession(
          sessionId: 'session-a',
          metrics: _metrics(type),
        );
        expect(db.documents['sessions/session-a']!['status'], 'completed');
        expect(
          db.documents['activityResults/session-a']!['activityType'],
          type.name,
        );
        expect(
          db.documents.containsKey('activeExecutionSessions/child-a'),
          isFalse,
        );
        final result = Map.of(db.documents['activityResults/session-a']!);
        await service.completeSession(
          sessionId: 'session-a',
          metrics: _metrics(type),
        );
        expect(db.documents['activityResults/session-a'], result);
        expect(db.reads.any((path) => path.startsWith('activities/')), isFalse);
      });
    }
    test('interrumpe tras $status sin leer activities', () async {
      final db = _MemoryFirestore(ActivityType.sequence)
        ..activityStatus = status;
      await _service(db).interruptSession('session-a');
      expect(db.documents['sessions/session-a']!['status'], 'interrupted');
      expect(
        db.documents.containsKey('activeExecutionSessions/child-a'),
        isFalse,
      );
      expect(db.documents.containsKey('activityResults/session-a'), isFalse);
    });
  }

  for (final afterCommit in [false, true]) {
    test(
      'reintento de red ${afterCommit ? 'después' : 'antes'} del commit',
      () async {
        final db = _MemoryFirestore(ActivityType.sequence);
        final service = _service(db);
        db.failNextCommit = afterCommit ? 'after' : 'before';
        await expectLater(
          service.completeSession(
            sessionId: 'session-a',
            metrics: _metrics(ActivityType.sequence),
          ),
          throwsA(isA<FirebaseException>()),
        );
        expect(
          db.documents.containsKey('activityResults/session-a'),
          afterCommit,
        );
        expect(
          db.documents.containsKey('activeExecutionSessions/child-a'),
          !afterCommit,
        );
        await service.completeSession(
          sessionId: 'session-a',
          metrics: _metrics(ActivityType.sequence),
        );
        await service.completeSession(
          sessionId: 'session-a',
          metrics: _metrics(ActivityType.sequence),
        );
        expect(
          db.documents.keys.where(
            (path) => path.startsWith('activityResults/'),
          ),
          hasLength(1),
        );
        expect(db.documents['sessions/session-a']!['status'], 'completed');
      },
    );
  }

  for (final code in ['unavailable', 'permission-denied']) {
    test(
      'conserva $code si Android enmascara el callback con unknown',
      () async {
        final original = FirebaseException(
          plugin: 'cloud_firestore',
          code: code,
        );
        final db = _MemoryFirestore(ActivityType.sequence)
          ..nextReadError = original
          ..maskCallbackError = true;
        final service = _service(db);
        await expectLater(
          service.completeSession(
            sessionId: 'session-a',
            metrics: _metrics(ActivityType.sequence),
          ),
          throwsA(same(original)),
        );
        expect(db.documents['sessions/session-a']!['status'], 'inProgress');
        expect(db.documents.containsKey('activityResults/session-a'), isFalse);
        expect(
          db.documents.containsKey('activeExecutionSessions/child-a'),
          isTrue,
        );
        await service.completeSession(
          sessionId: 'session-a',
          metrics: _metrics(ActivityType.sequence),
        );
        expect(db.documents['sessions/session-a']!['status'], 'completed');
        expect(
          db.documents.keys.where(
            (path) => path.startsWith('activityResults/'),
          ),
          hasLength(1),
        );
      },
    );
  }

  test('no oculta unknown nativo sin causa del callback', () async {
    final db = _MemoryFirestore(ActivityType.sequence)
      ..failNextCommit = 'unknown';
    await expectLater(
      _service(db).completeSession(
        sessionId: 'session-a',
        metrics: _metrics(ActivityType.sequence),
      ),
      throwsA(
        isA<FirebaseException>().having((e) => e.code, 'code', 'unknown'),
      ),
    );
    expect(db.documents['sessions/session-a']!['status'], 'inProgress');
    expect(db.documents.containsKey('activityResults/session-a'), isFalse);
  });

  test('un reintento antiguo no libera un bloqueo nuevo', () async {
    final db = _MemoryFirestore(ActivityType.sequence);
    final service = _service(db);
    await service.completeSession(
      sessionId: 'session-a',
      metrics: _metrics(ActivityType.sequence),
    );
    db.documents['activeExecutionSessions/child-a'] = {
      ...db.lock,
      'sessionId': 'session-new',
    };
    await service.completeSession(
      sessionId: 'session-a',
      metrics: _metrics(ActivityType.sequence),
    );
    expect(
      db.documents['activeExecutionSessions/child-a']!['sessionId'],
      'session-new',
    );
  });

  test(
    'un bloqueo ajeno impide la finalización sin escrituras parciales',
    () async {
      final db = _MemoryFirestore(ActivityType.sequence);
      db.documents['activeExecutionSessions/child-a']!['sessionId'] = 'other';
      await expectLater(
        _service(db).completeSession(
          sessionId: 'session-a',
          metrics: _metrics(ActivityType.sequence),
        ),
        throwsA(isA<ActiveExecutionSessionDataException>()),
      );
      expect(db.documents['sessions/session-a']!['status'], 'inProgress');
      expect(db.documents.containsKey('activityResults/session-a'), isFalse);
      expect(
        db.documents['activeExecutionSessions/child-a']!['sessionId'],
        'other',
      );
    },
  );

  test('otra cuenta no puede finalizar la sesión', () async {
    final db = _MemoryFirestore(ActivityType.sequence);
    await expectLater(
      _service(db, uid: 'another-child').completeSession(
        sessionId: 'session-a',
        metrics: _metrics(ActivityType.sequence),
      ),
      throwsStateError,
    );
    expect(db.documents['sessions/session-a']!['status'], 'inProgress');
    expect(db.documents.containsKey('activityResults/session-a'), isFalse);
  });
}

ActivityExecutionSessionService _service(
  _MemoryFirestore db, {
  String uid = 'child-auth',
}) => ActivityExecutionSessionService(
  auth: _Auth(uid),
  firestoreService: FirestoreService(firestore: db),
);

ActivityExecutionMetrics _metrics(ActivityType type) => switch (type) {
  ActivityType.sequence => SequenceExecutionMetrics(
    itemsCount: 2,
    checksCount: 1,
  ),
  ActivityType.matching => MatchingExecutionMetrics(
    relationsCompleted: 2,
    checksCount: 1,
  ),
  ActivityType.emotion => EmotionExecutionMetrics(exercisesReviewed: 2),
  ActivityType.pictogram => PictogramExecutionMetrics(interactionsCount: 2),
  ActivityType.dragDrop => DragDropExecutionMetrics(
    itemsPlaced: 2,
    checksCount: 1,
  ),
  ActivityType.tracing => TracingExecutionMetrics(
    practiceCompleted: true,
    strokesCount: 1,
  ),
  ActivityType.timer => TimerExecutionMetrics(
    configuredDurationSeconds: 5,
    elapsedSeconds: 5,
  ),
  ActivityType.motor => MotorExecutionMetrics(stepsVisited: 2),
};

class _Auth extends Fake implements FirebaseAuth {
  final String uid;
  _Auth(this.uid);
  @override
  User get currentUser => _User(uid);
}

class _User extends Fake implements User {
  @override
  final String uid;
  _User(this.uid);
}

// This fake deliberately rejects any activity read. It exercises the real Dart
// service; authorization and atomicity are additionally tested in the Emulator.
class _MemoryFirestore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  final reads = <String>[];
  late final Map<String, dynamic> lock;
  set activityStatus(String value) =>
      documents['activities/activity-a']!['status'] = value;
  String? failNextCommit;
  Object? nextReadError;
  bool maskCallbackError = false;
  _MemoryFirestore(ActivityType type) {
    documents['activities/activity-a'] = {
      'type': type.name,
      'status': 'assigned',
    };
    final startedAt = Timestamp.fromDate(DateTime.utc(2026, 10, 1));
    documents['sessions/session-a'] = {
      'id': 'session-a',
      'activityId': 'activity-a',
      'therapyId': 'therapy-a',
      'childId': 'child-a',
      'psychologistId': 'psych-a',
      'childUserId': 'child-auth',
      'status': 'inProgress',
      'startedAt': startedAt,
    };
    lock = {
      'sessionId': 'session-a',
      'activityId': 'activity-a',
      'childId': 'child-a',
      'psychologistId': 'psych-a',
      'childUserId': 'child-auth',
      'startedAt': startedAt,
    };
    documents['activeExecutionSessions/child-a'] = Map.of(lock);
  }
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _Collection(collectionPath);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = _Transaction(this);
    final T value;
    try {
      value = await transactionHandler(transaction);
    } catch (_) {
      if (maskCallbackError) {
        throw FirebaseException(plugin: 'cloud_firestore', code: 'unknown');
      }
      rethrow;
    }
    final failure = failNextCommit;
    failNextCommit = null;
    if (failure == 'unknown') {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unknown');
    }
    if (failure == 'before')
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    for (final operation in transaction.pending) {
      operation();
    }
    if (failure == 'after')
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    return value;
  }
}

// SDK test double only; never used by the application.
// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final String collectionPath;
  _Collection(this.collectionPath);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Reference('$collectionPath/${path ?? 'new-session'}');
}

// SDK test double only; never used by the application.
// ignore: subtype_of_sealed_class
class _Reference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  @override
  final String path;
  _Reference(this.path);
  @override
  String get id => path.split('/').last;
}

// SDK test double only; never used by the application.
// ignore: subtype_of_sealed_class
class _Snapshot<T> extends Fake implements DocumentSnapshot<T> {
  final DocumentReference<T> referenceValue;
  final T? value;
  _Snapshot(this.referenceValue, this.value);
  @override
  String get id => referenceValue.id;
  @override
  bool get exists => value != null;
  @override
  T? data() => value;
  @override
  SnapshotMetadata get metadata => _Metadata();
}

class _Metadata extends Fake implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;
}

class _Transaction extends Fake implements Transaction {
  final _MemoryFirestore db;
  final pending = <void Function()>[];
  _Transaction(this.db);
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> documentReference,
  ) async {
    db.reads.add(documentReference.path);
    final readError = db.nextReadError;
    db.nextReadError = null;
    if (readError != null) throw readError;
    if (documentReference.path.startsWith('activities/')) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    final data = db.documents[documentReference.path];
    return _Snapshot<T>(
      documentReference,
      data == null ? null : Map<String, dynamic>.from(data) as T,
    );
  }

  Map<String, dynamic> _confirmed(Map data) => data.map(
    (key, value) => MapEntry(
      key as String,
      value is FieldValue
          ? Timestamp.fromDate(DateTime.utc(2026, 10, 2))
          : value,
    ),
  );
  @override
  Transaction update(
    DocumentReference documentReference,
    Map<Object, Object?> data,
  ) {
    pending.add(
      () => db.documents[documentReference.path]!.addAll(_confirmed(data)),
    );
    return this;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> documentReference,
    T data, [
    SetOptions? options,
  ]) {
    pending.add(
      () => db.documents[documentReference.path] = _confirmed(data as Map),
    );
    return this;
  }

  @override
  Transaction delete(DocumentReference documentReference) {
    pending.add(() => db.documents.remove(documentReference.path));
    return this;
  }
}
