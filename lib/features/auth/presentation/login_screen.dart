import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/auth_error_mapper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/calmatea_button.dart';
import '../../../core/widgets/calmatea_text_field.dart';
import '../../../services/auth_service.dart';

/// Pantalla de Inicio de Sesión — CalmaTEA v0.1.
/// Conectada a AuthService real. AuthGate gestiona automáticamente la navegación post-login.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _authService = AuthService();

  bool _obscurePass = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signIn(
        email: _emailCtrl.text,
        password: _passCtrl.text,
      );

      // Si la pantalla fue abierta mediante push sobre AuthGate, limpiamos la pila
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      // AuthGate detecta automáticamente el cambio de sesión y enruta según rol.
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
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Ícono / Logo ─────────────────────────────
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.spa_rounded,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Iniciar sesión',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bienvenido a ${AppConstants.appName}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),

                    // ── Correo electrónico ───────────────────────
                    CalmaTeaTextField(
                      controller: _emailCtrl,
                      label: 'Correo electrónico',
                      hint: 'ejemplo@correo.com',
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
                    const SizedBox(height: 10),

                    // ── Olvidaste tu contraseña ──────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pushNamed(
                                  context,
                                  RouteNames.forgotPassword,
                                ),
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Botón Iniciar sesión ─────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: CalmaTeaButton(
                        text: 'Iniciar sesión',
                        isLoading: _isLoading,
                        onPressed: _handleLogin,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Divider(),
                    const SizedBox(height: 16),

                    // ── Crear cuenta ─────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: CalmaTeaButton(
                        text: 'Crear cuenta profesional',
                        isOutlined: true,
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pushNamed(
                                  context,
                                  RouteNames.register,
                                ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Acceso para profesionales de salud y terapeutas',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                          ),
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
