import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/models/activity_model.dart';

void main() {
  test('deserializa tipos y estados reconocidos sin alterar datos', () {
    final activity = ActivityModel.fromMap(_validMap(), id: 'document-id');

    expect(activity.id, 'document-id');
    expect(activity.type, ActivityType.timer);
    expect(activity.status, ActivityStatus.inProgress);
  });

  test('rechaza un tipo desconocido en vez de abrir Sequence', () {
    final map = _validMap()..['type'] = 'unknownEngine';

    expect(() => ActivityModel.fromMap(map), throwsFormatException);
  });

  test('rechaza un estado desconocido en vez de asumir assigned', () {
    final map = _validMap()..['status'] = 'unknownStatus';

    expect(() => ActivityModel.fromMap(map), throwsFormatException);
  });
}

Map<String, dynamic> _validMap() {
  return {
    'therapyId': 'therapy-id',
    'childId': 'child-id',
    'psychologistId': 'psychologist-id',
    'title': 'Actividad',
    'description': '',
    'type': 'timer',
    'difficulty': 1,
    'instructions': '',
    'configuration': {'version': 1, 'durationSeconds': 30},
    'status': 'inProgress',
    'createdAt': '2026-10-08T12:00:00.000Z',
    'updatedAt': null,
  };
}
