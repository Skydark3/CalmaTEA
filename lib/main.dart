import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/phase10_feature_flags.dart';
import 'core/constants/app_constants.dart';
import 'core/constants/route_names.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/routes/app_router.dart';
import 'core/services/app_state.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    Phase10Features.validateEnvironment();
    await FirebaseBootstrap.initialize();
  } catch (_) {
    runApp(const _FirebaseInitializationErrorApp());
    return;
  }

  runApp(
    // AppState se conserva en el árbol raíz temporalmente para mantener
    // retrocompatibilidad con las pantallas legacy que aún lo consumen.
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const CalmaTeaApp(),
    ),
  );
}

class CalmaTeaApp extends StatelessWidget {
  const CalmaTeaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: RouteNames.splash,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}

// Alias de retrocompatibilidad para tests existentes
typedef TeaApp = CalmaTeaApp;

class _FirebaseInitializationErrorApp extends StatelessWidget {
  const _FirebaseInitializationErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No pudimos conectar con los servicios de CalmaTEA. '
                'Comprueba el entorno configurado e intenta nuevamente.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
