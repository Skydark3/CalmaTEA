import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/app_state.dart';
import '../../../core/theme/app_colors.dart';

/// Pantalla de Progreso del Usuario — Pantalla 10 del mockup.
/// Muestra estadísticas semanales y desempeño por actividad.
class UserProgressScreen extends StatefulWidget {
  const UserProgressScreen({super.key});

  @override
  State<UserProgressScreen> createState() => _UserProgressScreenState();
}

class _UserProgressScreenState extends State<UserProgressScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progreso del usuario'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Actividades'),
            Tab(text: 'Rutina'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GeneralTab(state: state),
          _ActivitiesTab(state: state),
          _RoutineTab(state: state),
        ],
      ),
    );
  }
}

// ── Pestaña General ──────────────────────────────────────────────────────
class _GeneralTab extends StatelessWidget {
  final AppState state;
  const _GeneralTab({required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card de usuario ──────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
                    child: Text(
                      state.userName[0],
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.userName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 18)),
                      Text('Usuario nivel ${state.userAge}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: AppColors.accent, size: 16),
                          const SizedBox(width: 4),
                          Text('${state.totalPoints} puntos',
                              style: const TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Estadísticas de la semana',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          // ── 3 métricas circulares ────────────────────────────
          Row(
            children: [
              Expanded(
                child: _CircleStat(
                  label: 'Rutinas\ncompletadas',
                  value: state.weeklyRoutineCompliance,
                  color: AppColors.primary,
                ),
              ),
              Expanded(
                child: _CircleStat(
                  label: 'Actividades\nrealizadas',
                  value: state.weeklyActivitiesCompleted,
                  color: AppColors.success,
                ),
              ),
              Expanded(
                child: _CircleStat(
                  label: 'Tiempo de\nactividades',
                  value: state.weeklyActivityTime,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _CircleStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 6,
                    backgroundColor: color.withValues(alpha: 0.15),
                    color: color,
                  ),
                  Text(
                    '${(value * 100).toInt()}%',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pestaña Actividades ──────────────────────────────────────────────────
class _ActivitiesTab extends StatelessWidget {
  final AppState state;
  const _ActivitiesTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final items = [
      _BarItem('Memoria visual', state.visualMemoryProgress, AppColors.cognitive),
      _BarItem('Asociación', state.associationProgress, AppColors.primary),
      _BarItem('Atención', state.attentionProgress, AppColors.primaryDark),
      _BarItem('Clasificación', state.classificationProgress, const Color(0xFF7B61FF)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Desempeño por actividad',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...items.map((item) => _ProgressBar(item: item)),
          const SizedBox(height: 24),
          if (state.activityHistory.isNotEmpty) ...[
            Text('Últimas actividades',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...state.activityHistory.take(5).map(
              (r) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: AppColors.success),
                  title: Text(r.activityName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${r.correctAnswers}/${r.totalQuestions} aciertos  •  ${r.formattedTime}'),
                  trailing: Text(
                    '${(r.accuracy * 100).toInt()}%',
                    style: TextStyle(
                      color: r.accuracy >= 0.7 ? AppColors.success : AppColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BarItem {
  final String label;
  final double value;
  final Color color;
  const _BarItem(this.label, this.value, this.color);
}

class _ProgressBar extends StatelessWidget {
  final _BarItem item;
  const _ProgressBar({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item.label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('${(item.value * 100).toInt()}%',
                  style: TextStyle(
                      color: item.color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: item.value,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
            color: item.color,
            backgroundColor: item.color.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }
}

// ── Pestaña Rutina ────────────────────────────────────────────────────────
class _RoutineTab extends StatelessWidget {
  final AppState state;
  const _RoutineTab({required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text('Cumplimiento de rutina',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: state.weeklyRoutineCompliance,
                    minHeight: 12,
                    borderRadius: BorderRadius.circular(6),
                    color: AppColors.primary,
                    backgroundColor: AppColors.cardBg,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(state.weeklyRoutineCompliance * 100).toInt()}% esta semana',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
