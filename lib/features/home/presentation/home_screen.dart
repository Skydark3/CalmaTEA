import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/routine_item.dart';

/// Pantalla Principal del Usuario — Pantalla 3 del mockup.
/// Muestra el saludo, el progreso del día y la rutina resumida.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final weekdays = ['lunes','martes','miércoles','jueves','viernes','sábado','domingo'];
    final months = ['enero','febrero','marzo','abril','mayo','junio','julio',
        'agosto','septiembre','octubre','noviembre','diciembre'];
    final dateStr =
        '${weekdays[now.weekday - 1].substring(0,1).toUpperCase()}${weekdays[now.weekday - 1].substring(1)}, ${now.day} de ${months[now.month - 1]}';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Text(
                state.userName.substring(0, 1),
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hola, ${state.userName}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('¡Hoy es un gran día!',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateStr,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            // ── Progreso del día ────────────────────────────────────
            _ProgressCard(state: state),
            const SizedBox(height: 24),
            // ── Rutina de hoy ───────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mi rutina de hoy',
                    style: Theme.of(context).textTheme.titleLarge),
                TextButton(
                  onPressed: () {},
                  child: const Text('Ver todas'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...state.dailyRoutine.take(4).map(
              (item) => _RoutineItemTile(item: item),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget de tarjeta de progreso ────────────────────────────────────────
class _ProgressCard extends StatelessWidget {
  final AppState state;
  const _ProgressCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Círculo de progreso ─────────────────────────────────
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: state.routineProgress,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${state.completedRoutineCount}/${state.dailyRoutine.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // ── Info ─────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tu progreso de hoy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Actividades completadas',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFC107), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${state.totalPoints} puntos',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tile individual de rutina ──────────────────────────────────────────
class _RoutineItemTile extends StatelessWidget {
  final RoutineItem item;
  const _RoutineItemTile({required this.item});

  Color get _statusColor {
    switch (item.status) {
      case RoutineStatus.completed:
        return AppColors.success;
      case RoutineStatus.inProgress:
        return AppColors.warning;
      case RoutineStatus.pending:
        return AppColors.pending;
    }
  }

  IconData get _statusIcon {
    switch (item.status) {
      case RoutineStatus.completed:
        return Icons.check_circle;
      case RoutineStatus.inProgress:
        return Icons.play_circle_filled;
      case RoutineStatus.pending:
        return Icons.radio_button_unchecked;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(item.iconEmoji, style: const TextStyle(fontSize: 24)),
          ),
        ),
        title: Text(item.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(item.time,
            style: const TextStyle(color: AppColors.textSecondary)),
        trailing: Icon(_statusIcon, color: _statusColor, size: 28),
      ),
    );
  }
}
