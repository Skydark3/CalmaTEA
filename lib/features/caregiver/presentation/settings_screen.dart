import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/splash_screen.dart';
import '../../../features/caregiver/presentation/caregiver_panel_screen.dart';

/// Pantalla de Configuración y Perfil — Pantalla 12 del mockup.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header del perfil ─────────────────────────────────
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    child: Text(
                      state.userName[0],
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.userName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      Text('${state.totalPoints} puntos',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            // ── Opciones ─────────────────────────────────────────
            _SettingsTile(
              icon: Icons.person_outline,
              title: 'Perfil',
              subtitle: 'Editar información',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              title: 'Notificaciones',
              subtitle: 'Recordatorios de actividades',
              trailing: Switch(
                value: true,
                onChanged: (_) {},
                activeThumbColor: AppColors.primary,
              ),
            ),
            _SettingsTile(
              icon: Icons.trending_up_outlined,
              title: 'Alertas de progreso',
              trailing: Switch(
                value: true,
                onChanged: (_) {},
                activeThumbColor: AppColors.primary,
              ),
            ),
            _SettingsTile(
              icon: Icons.language_outlined,
              title: 'Idioma',
              subtitle: 'Español',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.dark_mode_outlined,
              title: 'Modo oscuro',
              trailing: Switch(
                value: false,
                onChanged: (_) {},
                activeThumbColor: AppColors.primary,
              ),
            ),
            _SettingsTile(
              icon: Icons.sync_outlined,
              title: 'Sincronización',
              subtitle: 'Última sincronización: hoy, 10:24',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.family_restroom_outlined,
              title: 'Panel familiar',
              subtitle: 'Ver panel del cuidador',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CaregiverPanelScreen()),
              ),
            ),
            const Divider(height: 32),
            // ── Cerrar sesión ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const SplashScreen()),
                    (_) => false,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Cerrar sesión',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 24),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(fontSize: 12))
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    );
  }
}
