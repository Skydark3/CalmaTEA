import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../models/activity_model.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/child_activity_service.dart';
import '../../child/child_shell.dart';
import '../../psychologist/psychologist_shell.dart';
import 'login_screen.dart';

/// AuthGate gestiona el enrutamiento reactivo según el estado de autenticación y rol.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: LoadingView(message: 'Verificando sesión...'),
          );
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        // Si existe un usuario autenticado, cargamos su perfil en Firestore
        return UserProfileResolver(uid: user.uid);
      },
    );
  }
}

typedef UserProfileLoader = Future<UserModel?> Function(String uid);
typedef AuthenticatedShellBuilder = Widget Function(UserModel user);

class UserProfileResolver extends StatefulWidget {
  final String uid;
  final UserProfileLoader? profileLoader;
  final Future<void> Function()? onSignOut;
  final Stream<List<ActivityModel>>? childActivitiesStream;
  final AuthenticatedShellBuilder? authenticatedShellBuilder;
  final Duration profileTimeout;

  const UserProfileResolver({
    super.key,
    required this.uid,
    this.profileLoader,
    this.onSignOut,
    this.childActivitiesStream,
    this.authenticatedShellBuilder,
    this.profileTimeout = const Duration(seconds: 20),
  });

  @override
  State<UserProfileResolver> createState() => _UserProfileResolverState();
}

class _UserProfileResolverState extends State<UserProfileResolver> {
  AuthService? _authServiceInstance;
  ChildActivityService? _childActivityServiceInstance;
  UserModel? _profile;
  Object? _profileError;
  bool _isLoading = true;
  int _requestVersion = 0;

  AuthService get _authService => _authServiceInstance ??= AuthService();

  ChildActivityService get _childActivityService =>
      _childActivityServiceInstance ??= ChildActivityService();

  @override
  void initState() {
    super.initState();
    _loadProfile(notify: false);
  }

  @override
  void didUpdateWidget(covariant UserProfileResolver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile({bool notify = true}) async {
    final requestVersion = ++_requestVersion;
    void beginLoading() {
      _isLoading = true;
      _profile = null;
      _profileError = null;
    }

    if (notify && mounted) {
      setState(beginLoading);
    } else {
      beginLoading();
    }

    try {
      final loader = widget.profileLoader ?? _authService.getUserProfile;
      final profile = await loader(widget.uid).timeout(widget.profileTimeout);
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _profile = profile;
        _profileError = profile == null
            ? StateError('El perfil autenticado no existe.')
            : null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _profileError = error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingView(message: 'Cargando perfil...'));
    }

    final error = _profileError;
    if (error != null || _profile == null) {
      return _ProfileLoadErrorView(
        error: error,
        onRetry: _loadProfile,
        onSignOut: widget.onSignOut ?? _authService.signOut,
      );
    }

    final userModel = _profile!;
    switch (userModel.role) {
      case UserRole.psychologist:
        return widget.authenticatedShellBuilder?.call(userModel) ??
            PsychologistShell(user: userModel);
      case UserRole.child:
        if (!userModel.hasValidChildLink) {
          return _InvalidChildLinkView(
            onRetry: _loadProfile,
            onSignOut: widget.onSignOut ?? _authService.signOut,
          );
        }
        return widget.authenticatedShellBuilder?.call(userModel) ??
            ChildShell(
              user: userModel,
              activitiesStream:
                  widget.childActivitiesStream ??
                  _childActivityService.watchAvailableActivities(),
              onSignOut: widget.onSignOut ?? _authService.signOut,
            );
    }
  }
}

class _ProfileLoadErrorView extends StatelessWidget {
  final Object? error;
  final Future<void> Function() onRetry;
  final Future<void> Function() onSignOut;

  const _ProfileLoadErrorView({
    required this.error,
    required this.onRetry,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final currentError = error;
    final isRoleError = currentError is FormatException;
    final isConnectivityError =
        currentError is TimeoutException ||
        (currentError is FirebaseException &&
            currentError.code == 'unavailable');
    final title = isRoleError
        ? 'No pudimos validar el tipo de cuenta'
        : isConnectivityError
        ? 'No pudimos conectar con tu perfil'
        : 'No pudimos cargar tu perfil';
    final message = isRoleError
        ? 'El rol asignado a esta cuenta no es válido o no tiene permisos de acceso reconocidos.'
        : isConnectivityError
        ? 'Comprueba tu conexión a Internet y vuelve a intentarlo.'
        : 'Ocurrió un inconveniente al consultar la información de tu cuenta.';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EmptyState(
                  icon: isRoleError
                      ? Icons.shield_outlined
                      : isConnectivityError
                      ? Icons.cloud_off_outlined
                      : Icons.error_outline_rounded,
                  title: title,
                  message: message,
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: onSignOut,
                      child: const Text('Cerrar sesión'),
                    ),
                    ElevatedButton(
                      onPressed: onRetry,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InvalidChildLinkView extends StatelessWidget {
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  const _InvalidChildLinkView({required this.onRetry, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EmptyState(
                  icon: Icons.link_off_rounded,
                  title: 'Cuenta sin vinculación',
                  message: 'Esta cuenta de paciente no está vinculada correctamente.',
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: onSignOut,
                      child: const Text('Cerrar sesión'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: onRetry,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
