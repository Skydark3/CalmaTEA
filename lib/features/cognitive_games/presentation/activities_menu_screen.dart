import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'visual_memory_screen.dart';
import 'association_screen.dart';
import 'attention_screen.dart';

/// Menú de Actividades Cognitivas — Pantalla 5 del mockup.
/// Muestra categorías: Cognitivas, Autonomía, Recreativas.
class ActivitiesMenuScreen extends StatefulWidget {
  const ActivitiesMenuScreen({super.key});

  @override
  State<ActivitiesMenuScreen> createState() => _ActivitiesMenuScreenState();
}

class _ActivitiesMenuScreenState extends State<ActivitiesMenuScreen>
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú de actividades'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Cognitivas'),
            Tab(text: 'Autonomía'),
            Tab(text: 'Recreativas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ActivityGrid(activities: _cognitiveActivities),
          _ActivityGrid(activities: _autonomyActivities),
          _ActivityGrid(activities: _recreationalActivities),
        ],
      ),
    );
  }
}

// ─── Datos de actividades ────────────────────────────────────────────────

final _cognitiveActivities = [
  _ActivityData(
    emoji: '🧠',
    title: 'Memoria visual',
    subtitle: 'Encuentra las parejas',
    color: AppColors.cognitive,
    screen: const VisualMemoryScreen(),
  ),
  _ActivityData(
    emoji: '🔗',
    title: 'Asociación',
    subtitle: 'Relaciona objetos',
    color: AppColors.primary,
    screen: const AssociationScreen(),
  ),
  _ActivityData(
    emoji: '👁️',
    title: 'Atención',
    subtitle: 'Observa la diferencia',
    color: AppColors.primaryDark,
    screen: const AttentionScreen(),
  ),
  _ActivityData(
    emoji: '📦',
    title: 'Clasificación',
    subtitle: 'Ordena por categoría',
    color: const Color(0xFF7B61FF),
    screen: const AssociationScreen(), // placeholder
  ),
  _ActivityData(
    emoji: '🎨',
    title: 'Reconocimiento de colores',
    subtitle: 'Identifica los colores',
    color: const Color(0xFFFF6B6B),
    screen: const AttentionScreen(), // placeholder
  ),
  _ActivityData(
    emoji: '🔢',
    title: 'Lógica',
    subtitle: 'Resuelve el patrón',
    color: const Color(0xFF4ECDC4),
    screen: const VisualMemoryScreen(), // placeholder
  ),
];

final _autonomyActivities = [
  _ActivityData(
    emoji: '🦷',
    title: 'Higiene bucal',
    subtitle: 'Aprende a cepillarte',
    color: AppColors.autonomy,
    screen: const AssociationScreen(),
  ),
  _ActivityData(
    emoji: '👗',
    title: 'Vestirse solo',
    subtitle: 'Sigue los pasos',
    color: AppColors.autonomy,
    screen: const AssociationScreen(),
  ),
];

final _recreationalActivities = [
  _ActivityData(
    emoji: '🎵',
    title: 'Ritmo musical',
    subtitle: 'Sigue el ritmo',
    color: AppColors.recreational,
    screen: const AttentionScreen(),
  ),
  _ActivityData(
    emoji: '🎨',
    title: 'Colorear',
    subtitle: 'Expresa tu creatividad',
    color: AppColors.recreational,
    screen: const AttentionScreen(),
  ),
];

// ─── Data class ──────────────────────────────────────────────────────────
class _ActivityData {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final Widget screen;
  const _ActivityData({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.screen,
  });
}

// ─── Grid de actividades ─────────────────────────────────────────────────
class _ActivityGrid extends StatelessWidget {
  final List<_ActivityData> activities;
  const _ActivityGrid({required this.activities});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final act = activities[i];
        return _ActivityTile(data: act);
      },
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final _ActivityData data;
  const _ActivityTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => data.screen),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(data.emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(data.subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
