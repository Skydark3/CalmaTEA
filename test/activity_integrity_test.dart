import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tea_app/features/psychologist/activities/presentation/edit_activity_screen.dart';
import 'package:tea_app/models/activity_model.dart';
import 'package:tea_app/models/child_model.dart';
import 'package:tea_app/models/therapy_model.dart';
import 'package:tea_app/services/activity_service.dart';
import 'package:tea_app/services/firestore_service.dart';

void main() {
  for (final type in ActivityType.values) {
    test('${type.name}: rechaza cambiar el tipo sin escribir', () async {
      final activity = _activity(type);
      final db = _ActivityFirestore(activity);
      final different = ActivityType.values.firstWhere((item) => item != type);
      await expectLater(
        _service(db).updateActivity(activity.copyWith(type: different)),
        throwsStateError,
      );
      expect(db.updates, isEmpty);
      expect(db.deletes, 0);
    });

    test(
      '${type.name}: permite cancelar sin enviar campos inmutables',
      () async {
        final activity = _activity(type);
        final db = _ActivityFirestore(activity);
        await _service(
          db,
        ).updateActivity(activity.copyWith(status: ActivityStatus.cancelled));
        expect(db.updates, hasLength(1));
        expect(db.updates.single['status'], 'cancelled');
        expect(db.updates.single.keys, isNot(contains('type')));
        for (final field in [
          'id',
          'childId',
          'therapyId',
          'psychologistId',
          'createdAt',
        ]) {
          expect(db.updates.single.keys, isNot(contains(field)));
        }
      },
    );
  }

  test(
    'deleteActivity rechaza el borrado y no cancela implícitamente',
    () async {
      final db = _ActivityFirestore(_activity(ActivityType.sequence));
      await expectLater(
        _service(db).deleteActivity('activity-a', 'psych-a'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Cancelada'),
          ),
        ),
      );
      expect(db.deletes, 0);
      expect(db.updates, isEmpty);
    },
  );

  test('la consulta del servicio rechaza un profesional ajeno', () async {
    final activity = _activity(ActivityType.sequence);
    final db = _ActivityFirestore(activity);
    await expectLater(
      _service(db).updateActivity(activity.copyWith(psychologistId: 'psych-b')),
      throwsStateError,
    );
    await expectLater(
      _service(db).deleteActivity(activity.id, 'psych-b'),
      throwsStateError,
    );
    expect(db.updates, isEmpty);
    expect(db.deletes, 0);
  });

  for (final configured in [false, true]) {
    testWidgets(
      'edición conserva tipo con configuración ${configured ? 'presente' : 'vacía'}',
      (tester) async {
        final activity = _activity(ActivityType.sequence).copyWith(
          configuration: configured
              ? {
                  'version': 1,
                  'items': [
                    {'id': 'step', 'label': 'Paso', 'order': 0},
                  ],
                }
              : {},
        );
        final now = DateTime(2026, 10, 1);
        final child = ChildModel(
          id: 'child-a',
          psychologistId: 'psych-a',
          fullName: 'Paciente demo',
          birthDate: DateTime(2014, 1, 1),
          supportLevel: 'Nivel 1',
          createdAt: now,
        );
        final therapy = TherapyModel(
          id: 'therapy-a',
          childId: child.id,
          psychologistId: 'psych-a',
          type: TherapyType.occupational,
          status: TherapyStatus.active,
          startDate: now,
          createdAt: now,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: EditActivityScreen(
              activity: activity,
              therapy: therapy,
              child: child,
              activityService: _service(_ActivityFirestore(activity)),
            ),
          ),
        );
        final typeField = tester.widget<DropdownButtonFormField<ActivityType>>(
          find.byType(DropdownButtonFormField<ActivityType>),
        );
        expect(typeField.onChanged, isNull);
        expect(typeField.initialValue, ActivityType.sequence);
        expect(
          tester
              .widget<Text>(
                find.text(
                  'El tipo se conserva después de asignar la actividad.',
                ),
              )
              .maxLines,
          3,
        );
        expect(
          find.text('El tipo se conserva después de asignar la actividad.'),
          findsOneWidget,
        );
        final statusFinder = find.byType(
          DropdownButtonFormField<ActivityStatus>,
        );
        await tester.scrollUntilVisible(
          statusFinder,
          250,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(
          tester
              .widget<DropdownButtonFormField<ActivityStatus>>(statusFinder)
              .onChanged,
          isNotNull,
        );
        expect(
          find.text(
            'Selecciona Cancelada para retirarla sin borrar su historial.',
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<Text>(
                find.text(
                  'Selecciona Cancelada para retirarla sin borrar su historial.',
                ),
              )
              .maxLines,
          3,
        );
      },
    );
  }
}

ActivityService _service(_ActivityFirestore db) =>
    ActivityService(firestoreService: FirestoreService(firestore: db));
ActivityModel _activity(ActivityType type) => ActivityModel(
  id: 'activity-a',
  therapyId: 'therapy-a',
  childId: 'child-a',
  psychologistId: 'psych-a',
  title: 'Actividad demo',
  description: '',
  type: type,
  difficulty: 1,
  instructions: 'Sigue las indicaciones',
  configuration: const {},
  status: ActivityStatus.assigned,
  createdAt: DateTime(2026, 10, 1),
);

class _ActivityFirestore extends Fake implements FirebaseFirestore {
  final ActivityModel activity;
  final updates = <Map<String, dynamic>>[];
  int deletes = 0;
  _ActivityFirestore(this.activity);
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    expect(collectionPath, 'activities');
    return _ActivityQuery(this);
  }
}

// SDK test double only, not a production subclass.
// ignore: subtype_of_sealed_class
class _ActivityQuery extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final _ActivityFirestore db;
  final bool matches;
  _ActivityQuery(this.db, {this.matches = true});
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #where) {
      final field = invocation.positionalArguments.single;
      final value = invocation.namedArguments[#isEqualTo];
      var nextMatches = matches;
      if (field == 'psychologistId') {
        nextMatches = nextMatches && value == db.activity.psychologistId;
      }
      if (field is FieldPath)
        nextMatches = nextMatches && value == db.activity.id;
      return _ActivityQuery(db, matches: nextMatches);
    }
    if (invocation.memberName == #limit) return this;
    if (invocation.memberName == #get)
      return Future<QuerySnapshot<Map<String, dynamic>>>.value(
        _ActivityQuerySnapshot(db, matches),
      );
    return super.noSuchMethod(invocation);
  }
}

class _ActivityQuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  final _ActivityFirestore db;
  final bool matches;
  _ActivityQuerySnapshot(this.db, this.matches);
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs =>
      matches ? [_ActivityDocument(db)] : [];
}

// SDK test double only, not a production subclass.
// ignore: subtype_of_sealed_class
class _ActivityDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  final _ActivityFirestore db;
  _ActivityDocument(this.db);
  @override
  Map<String, dynamic> data() => db.activity.toMap();
  @override
  DocumentReference<Map<String, dynamic>> get reference =>
      _ActivityReference(db);
}

// SDK test double only, not a production subclass.
// ignore: subtype_of_sealed_class
class _ActivityReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final _ActivityFirestore db;
  _ActivityReference(this.db);
  @override
  Future<void> update(Map<Object, Object?> data) async =>
      db.updates.add(Map<String, dynamic>.from(data));
  @override
  Future<void> delete() async {
    db.deletes++;
  }
}
