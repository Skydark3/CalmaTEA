import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/calmatea_button.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../models/psychologist_model.dart';
import '../../../../models/user_model.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/psychologist_service.dart';

/// Pantalla del Perfil del Psicólogo (Pestaña "Perfil").
class PsychologistProfileScreen extends StatefulWidget {
  final UserModel user;

  const PsychologistProfileScreen({
    super.key,
    required this.user,
  });

  @override
  State<PsychologistProfileScreen> createState() =>
      _PsychologistProfileScreenState();
}

class _PsychologistProfileScreenState extends State<PsychologistProfileScreen> {
  final _psychologistService = PsychologistService();
  final _authService = AuthService();

  late Future<PsychologistModel?> _profileFuture;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadPsychologistData();
  }

  void _loadPsychologistData() {
    setState(() {
      _profileFuture =
          _psychologistService.getPsychologistProfile(widget.user.id);
    });
  }

  Future<void> _handleSignOut() async {
    setState(() => _isLoggingOut = true);
    try {
      await _authService.signOut();
      // AuthGate detecta automáticamente la transición User -> null y regresa al Login
    } catch (_) {
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
        title: const Text('Perfil profesional'),
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<PsychologistModel?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(
              message: 'Cargando información profesional...',
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No pudimos cargar tu información.',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadPsychologistData,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          final psychologist = snapshot.data;
          final fullName =
              psychologist?.fullName.isNotEmpty == true
                  ? psychologist!.fullName
                  : widget.user.name;
          final email =
              psychologist?.email.isNotEmpty == true
                  ? psychologist!.email
                  : widget.user.email;
          final specialty =
              psychologist?.specialty?.isNotEmpty == true
                  ? psychologist!.specialty!
                  : 'No especificado';
          final workCenter =
              psychologist?.workCenter?.isNotEmpty == true
                  ? psychologist!.workCenter!
                  : 'No especificado';
          final license =
              psychologist?.professionalLicense?.isNotEmpty == true
                  ? psychologist!.professionalLicense!
                  : 'No especificado';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              children: [
                // ── Tarjeta de cabecera con avatar ───────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor:
                            AppColors.primaryLight.withValues(alpha: 0.25),
                        child: Text(
                          fullName.isNotEmpty
                              ? fullName[0].toUpperCase()
                              : 'P',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        fullName,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mintLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.mint),
                        ),
                        child: const Text(
                          'Psicólogo / Terapeuta',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Tarjeta de información profesional ───────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Información profesional',
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 16),
                      _ProfileInfoRow(
                        label: 'Especialidad',
                        value: specialty,
                        icon: Icons.psychology_outlined,
                      ),
                      const Divider(height: 24),
                      _ProfileInfoRow(
                        label: 'Centro de trabajo',
                        value: workCenter,
                        icon: Icons.business_outlined,
                      ),
                      const Divider(height: 24),
                      _ProfileInfoRow(
                        label: 'Colegiatura / Licencia',
                        value: license,
                        icon: Icons.badge_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Botón Cerrar Sesión ──────────────────────────────
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
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProfileInfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: value == 'No especificado'
                          ? AppColors.pending
                          : AppColors.textPrimary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
