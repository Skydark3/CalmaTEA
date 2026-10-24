import 'package:flutter/material.dart';
import '../models/routine_item.dart';
import '../models/activity_result.dart';

/// Estado global de la aplicación TEA usando Provider (ChangeNotifier).
/// Gestiona la rutina diaria, historial de actividades y progreso semanal.
class AppState extends ChangeNotifier {
  // ─── Datos del usuario ────────────────────────────────────────────────
  String _userName = 'Alejandro';
  int _userAge = 3; // nivel de usuario
  int _totalPoints = 120;

  String get userName => _userName;
  int get userAge => _userAge;
  int get totalPoints => _totalPoints;

  // ─── Rutina diaria ────────────────────────────────────────────────────
  List<RoutineItem> _dailyRoutine = [
    RoutineItem(id: 'r1', title: 'Higiene personal',     iconEmoji: '🧼', time: '08:00', status: RoutineStatus.completed),
    RoutineItem(id: 'r2', title: 'Desayuno',             iconEmoji: '🍳', time: '08:30', status: RoutineStatus.completed),
    RoutineItem(id: 'r3', title: 'Actividad cognitiva',  iconEmoji: '🧩', time: '09:00', status: RoutineStatus.inProgress),
    RoutineItem(id: 'r4', title: 'Actividad física',     iconEmoji: '🏃', time: '11:00', status: RoutineStatus.pending),
    RoutineItem(id: 'r5', title: 'Almuerzo',             iconEmoji: '🍽️', time: '12:00', status: RoutineStatus.pending),
    RoutineItem(id: 'r6', title: 'Tarea de aprendizaje', iconEmoji: '📚', time: '15:00', status: RoutineStatus.pending),
    RoutineItem(id: 'r7', title: 'Tiempo libre',         iconEmoji: '🎮', time: '17:00', status: RoutineStatus.pending),
    RoutineItem(id: 'r8', title: 'Prepararse para dormir', iconEmoji: '🌙', time: '20:00', status: RoutineStatus.pending),
  ];

  List<RoutineItem> get dailyRoutine => _dailyRoutine;

  int get completedRoutineCount =>
      _dailyRoutine.where((r) => r.isCompleted).length;

  double get routineProgress =>
      _dailyRoutine.isEmpty ? 0 : completedRoutineCount / _dailyRoutine.length;

  void completeRoutineItem(String id) {
    final idx = _dailyRoutine.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _dailyRoutine[idx] = _dailyRoutine[idx].copyWith(status: RoutineStatus.completed);
      _totalPoints += 10;
      notifyListeners();
    }
  }

  // ─── Historial de actividades ─────────────────────────────────────────
  final List<ActivityResult> _activityHistory = [];
  List<ActivityResult> get activityHistory => List.unmodifiable(_activityHistory);

  void addActivityResult(ActivityResult result) {
    _activityHistory.insert(0, result);
    _totalPoints += (result.correctAnswers * 5);
    notifyListeners();
  }

  // ─── Progreso semanal (métricas) ─────────────────────────────────────
  double get weeklyRoutineCompliance => 0.78;
  double get weeklyActivitiesCompleted => 0.66;
  double get weeklyActivityTime => 0.82;

  // ─── Actividades cognitivas por categoría ────────────────────────────
  double get visualMemoryProgress => 0.80;
  double get associationProgress => 0.60;
  double get attentionProgress => 0.70;
  double get classificationProgress => 0.90;

  // ─── Usuario ─────────────────────────────────────────────────────────
  void setUserName(String name) {
    _userName = name;
    notifyListeners();
  }
}
