import 'package:firebase_auth/firebase_auth.dart';

import '../features/psychologist/dashboard/models/psychologist_execution_metrics.dart';
import '../models/activity_execution_session_model.dart';
import 'firestore_service.dart';

abstract interface class PsychologistExecutionMetricsDataSource {
  Future<PsychologistExecutionMetrics> loadMetrics({
    required String psychologistId,
  });
}

typedef PsychologistExecutionCountLoader = Future<List<int?>> Function();

/// Reconstruye un resumen coherente a partir de agregaciones independientes.
///
/// Firestore no garantiza que varias consultas `count()` pertenezcan a una
/// misma instantanea. Un unico reintento evita presentar como corrupcion un
/// cambio concurrente; una incoherencia persistente continua siendo un error.
class PsychologistExecutionMetricsAggregator {
  final PsychologistExecutionCountLoader _loadCounts;

  const PsychologistExecutionMetricsAggregator({
    required PsychologistExecutionCountLoader loadCounts,
  }) : _loadCounts = loadCounts;

  Future<PsychologistExecutionMetrics> loadConsistentMetrics() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final counts = await _loadCounts();
      if (counts.length != 4 || counts.any((count) => count == null)) {
        throw const PsychologistExecutionMetricsDataException(
          'Firestore no devolvio uno de los conteos solicitados.',
        );
      }

      try {
        return PsychologistExecutionMetrics(
          totalExecutions: counts[0]!,
          completedExecutions: counts[1]!,
          interruptedExecutions: counts[2]!,
          unclosedExecutions: counts[3]!,
        );
      } on ArgumentError catch (error) {
        if (attempt == 1) {
          throw PsychologistExecutionMetricsDataException(
            'Los conteos cambiaron durante la consulta: ${error.message}',
          );
        }
      }
    }

    throw const PsychologistExecutionMetricsDataException(
      'No fue posible obtener conteos coherentes.',
    );
  }
}

class PsychologistExecutionMetricsAccessDenied implements Exception {
  const PsychologistExecutionMetricsAccessDenied();
}

class PsychologistExecutionMetricsDataException implements Exception {
  final String message;

  const PsychologistExecutionMetricsDataException(this.message);

  @override
  String toString() => message;
}

/// Obtiene contadores descriptivos mediante agregaciones de Firestore.
class PsychologistExecutionMetricsService
    implements PsychologistExecutionMetricsDataSource {
  final FirebaseAuth _auth;
  final FirestoreService _firestoreService;

  PsychologistExecutionMetricsService({
    FirebaseAuth? auth,
    FirestoreService? firestoreService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestoreService = firestoreService ?? FirestoreService();

  @override
  Future<PsychologistExecutionMetrics> loadMetrics({
    required String psychologistId,
  }) async {
    final normalizedId = psychologistId.trim();
    final authenticatedId = _auth.currentUser?.uid;
    if (normalizedId.isEmpty ||
        normalizedId.contains('/') ||
        authenticatedId == null ||
        authenticatedId != normalizedId) {
      throw const PsychologistExecutionMetricsAccessDenied();
    }

    final profile = await _firestoreService.usersCollection
        .doc(authenticatedId)
        .get();
    if (!profile.exists || profile.data()?['role'] != 'psychologist') {
      throw const PsychologistExecutionMetricsAccessDenied();
    }

    final ownedSessions = _firestoreService.sessionsCollection.where(
      'psychologistId',
      isEqualTo: authenticatedId,
    );
    return PsychologistExecutionMetricsAggregator(
      loadCounts: () async {
        final snapshots = await Future.wait([
          ownedSessions.count().get(),
          ownedSessions
              .where(
                'status',
                isEqualTo: ActivityExecutionSessionStatus.completed.name,
              )
              .count()
              .get(),
          ownedSessions
              .where(
                'status',
                isEqualTo: ActivityExecutionSessionStatus.interrupted.name,
              )
              .count()
              .get(),
          ownedSessions
              .where(
                'status',
                isEqualTo: ActivityExecutionSessionStatus.inProgress.name,
              )
              .count()
              .get(),
        ]);
        return snapshots.map((snapshot) => snapshot.count).toList();
      },
    ).loadConsistentMetrics();
  }
}
