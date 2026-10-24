import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/user_model.dart';

class ChildProfileScreen extends StatefulWidget {
  final UserModel user;
  final Future<void> Function() onSignOut;

  const ChildProfileScreen({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() => _isSigningOut = true);
    try {
      await widget.onSignOut();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos cerrar la sesión. Inténtalo nuevamente.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        children: [
          Text(
            'Mi perfil',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 28),
          const Center(
            child: CircleAvatar(
              radius: 42,
              backgroundColor: AppColors.mintLight,
              foregroundColor: AppColors.primaryDark,
              child: Icon(Icons.person_rounded, size: 48),
            ),
          ),
          const SizedBox(height: 28),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  _ProfileItem(
                    icon: Icons.badge_outlined,
                    label: 'Nombre',
                    value: widget.user.name,
                  ),
                  const Divider(height: 1),
                  _ProfileItem(
                    icon: Icons.email_outlined,
                    label: 'Correo',
                    value: widget.user.email,
                  ),
                  const Divider(height: 1),
                  const _ProfileItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Rol',
                    value: 'Paciente',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _isSigningOut ? null : _signOut,
            icon: _isSigningOut
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
            label: Text(_isSigningOut ? 'Cerrando sesión...' : 'Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 26),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
