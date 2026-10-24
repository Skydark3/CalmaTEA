import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/auth_error_mapper.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/calmatea_button.dart';
import '../../../core/widgets/calmatea_text_field.dart';
import '../../../services/auth_service.dart';

/// Pantalla de Recuperación de Contraseña — CalmaTEA v0.1.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      await _authService.sendPasswordReset(email: _emailCtrl.text);

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Mensaje neutral de seguridad: no revela si la cuenta existe o no
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si existe una cuenta asociada a este correo, recibirás instrucciones para restablecer tu contraseña.',
          ),
          backgroundColor: AppColors.primaryDark,
          duration: Duration(seconds: 5),
        ),
      );

      // Regresar al login tras notificar
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      // Si es un error de red mostramos el aviso, de lo contrario mostramos el mensaje neutral por seguridad
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
        title: const Text('Recuperar contraseña'),
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
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.lock_reset_rounded,
                          size: 38,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '¿Olvidaste tu contraseña?',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ingresa el correo electrónico asociado a tu cuenta y te enviaremos las instrucciones para restablecerla.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
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
                    const SizedBox(height: 24),

                    // ── Botón Enviar ─────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: CalmaTeaButton(
                        text: 'Enviar instrucciones',
                        isLoading: _isLoading,
                        onPressed: _handleSendResetEmail,
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
