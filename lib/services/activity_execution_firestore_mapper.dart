import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/activity_execution_result_model.dart';
import '../models/activity_execution_session_model.dart';

/// Traduce documentos Firestore sin introducir Firebase en los modelos.
abstract final class ActivityExecutionFirestoreMapper {
  static ActivityExecutionSessionModel sessionFromData({
    required String id,
    required Map<String, dynamic> data,
    bool hasPendingWrites = false,
  }) {
    final mapped = Map<String, dynamic>.from(data);
    mapped['startedAt'] = _requiredTimestamp(
      mapped['startedAt'],
      field: 'startedAt',
      hasPendingWrites: hasPendingWrites,
    ).toIso8601String();

    if (mapped.containsKey('endedAt') && mapped['endedAt'] != null) {
      mapped['endedAt'] = _requiredTimestamp(
        mapped['endedAt'],
        field: 'endedAt',
        hasPendingWrites: hasPendingWrites,
      ).toIso8601String();
    }

    return ActivityExecutionSessionModel.fromMap(mapped, id: id);
  }

  static ActivityExecutionResultModel resultFromData({
    required String id,
    required Map<String, dynamic> data,
    bool hasPendingWrites = false,
  }) {
    final mapped = Map<String, dynamic>.from(data);
    mapped['completedAt'] = _requiredTimestamp(
      mapped['completedAt'],
      field: 'completedAt',
      hasPendingWrites: hasPendingWrites,
    ).toIso8601String();

    return ActivityExecutionResultModel.fromMap(mapped, id: id);
  }

  static DateTime _requiredTimestamp(
    Object? value, {
    required String field,
    required bool hasPendingWrites,
  }) {
    if (value is Timestamp) return value.toDate();
    if (value == null && hasPendingWrites) {
      throw StateError(
        'El timestamp $field todavía está pendiente del servidor.',
      );
    }
    throw FormatException('$field no contiene un Timestamp válido.');
  }
}
