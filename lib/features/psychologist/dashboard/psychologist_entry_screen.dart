import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/calmatea_button.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';

/// Pantalla temporal de verificación para el rol de psicólogo (Fase 3).
/// Valida la autenticación, carga del perfil de Firestore, enrutamiento por rol y cierre de sesión.
class PsychologistEntryScreen extends StatefulWidget {
  final UserModel user;

  const PsychologistEntryScreen({
    super.key,
    required this.user,
  });

  @override
  State<PsychologistEntryScreen> createState() => _PsychologistEntryScreenState();
}

class _PsychologistEntryScreenState extends State<PsychologistEntryScreen> {
  final _authService = AuthService();
  bool _isLoggingOut = false;

  Future<void> _handleSignOut() async {
    setState(() => _isLoggingOut = true);
    try {
      await _authService.signOut();
      // AuthGate detectará automáticamente que user es null y mostrará LoginScreen
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al cerrar sesión. Intenta nuevamente.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso Profesional'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.mintLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.mint, width: 2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.verified_user_rounded,
                    size: 48,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '¡Bienvenido a ${AppConstants.appName}!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Sesión profesional activa',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Text(
                            widget.user.name.isNotEmpty
                                ? widget.user.name.substring(0, 1).toUpperCase()
                                : 'P',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          widget.user.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(widget.user.email),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Rol asignado:'),
                          Text(
                            widget.user.role.name.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: CalmaTeaButton(
                  text: 'Cerrar sesión',
                  isOutlined: true,
                  isLoading: _isLoggingOut,
                  icon: Icons.logout_rounded,
                  onPressed: _handleSignOut,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
