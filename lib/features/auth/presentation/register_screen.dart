import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/auth_error_mapper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/calmatea_button.dart';
import '../../../core/widgets/calmatea_text_field.dart';
import '../../../services/auth_service.dart';

/// Pantalla de Registro Profesional — CalmaTEA v0.1.
/// Registra al profesional en Firebase Auth y crea los documentos en users/{uid} y psychologists/{uid}.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _authService = AuthService();

  bool _obscurePass = true;
  bool _obscureConfirmPass = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_passCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Las contraseñas no coinciden.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.registerPsychologist(
        fullName: _nameCtrl.text,
        email: _emailCtrl.text,
        password: _passCtrl.text,
      );

      // Si el registro fue exitoso, limpiamos la pila de navegación para que AuthGate tome el control
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final message = AuthErrorMapper.toSpanishMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta profesional'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEEF6FF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mintLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.mint),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.badge_outlined, size: 18, color: AppColors.primaryDark),
                          SizedBox(width: 8),
                          Text(
                            'Registro para Psicólogos y Terapeutas',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Únete a ${AppConstants.appName}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Gestiona pacientes, terapias e indicadores de progreso',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),

                    // ── Nombre completo ─────────────────────────
                    CalmaTeaTextField(
                      controller: _nameCtrl,
                      label: 'Nombre y apellido',
                      hint: 'Lic. Juan Pérez',
                      prefixIcon: const Icon(Icons.person_outline),
                      validator: Validators.name,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),

                    // ── Correo electrónico ───────────────────────
                    CalmaTeaTextField(
                      controller: _emailCtrl,
                      label: 'Correo electrónico profesional',
                      hint: 'terapeuta@correo.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                      validator: Validators.email,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),

                    // ── Contraseña ──────────────────────────────
                    CalmaTeaTextField(
                      controller: _passCtrl,
                      label: 'Contraseña',
                      hint: 'Mínimo 6 caracteres',
                      obscureText: _obscurePass,
                      prefixIcon: const Icon(Icons.lock_outline),
                      enabled: !_isLoading,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 16),

                    // ── Confirmar Contraseña ────────────────────
                    CalmaTeaTextField(
                      controller: _confirmPassCtrl,
                      label: 'Confirmar contraseña',
                      hint: 'Repite tu contraseña',
                      obscureText: _obscureConfirmPass,
                      prefixIcon: const Icon(Icons.lock_clock_outlined),
                      enabled: !_isLoading,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPass = !_obscureConfirmPass,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Confirma tu contraseña';
                        }
                        if (value != _passCtrl.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // ── Botón Registrarse ────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: CalmaTeaButton(
                        text: 'Registrarme',
                        isLoading: _isLoading,
                        onPressed: _handleRegister,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Ya tienes cuenta ─────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('¿Ya tienes una cuenta?'),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  if (Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                  } else {
                                    Navigator.pushReplacementNamed(
                                      context,
                                      RouteNames.login,
                                    );
                                  }
                                },
                          child: const Text('Inicia sesión'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
