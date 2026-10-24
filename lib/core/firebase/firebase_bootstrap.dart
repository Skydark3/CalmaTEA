import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Inicializa Firebase y, solo bajo una compilacion debug explicita, redirige
/// Auth y Firestore a la Firebase Emulator Suite local.
class FirebaseBootstrap {
  static const String _useEmulatorsRaw = String.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
    defaultValue: 'false',
  );
  static const bool useEmulators = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
    defaultValue: false,
  );

  static const String emulatorProjectId = 'demo-calmatea-local';
  static const int authEmulatorPort = 9099;
  static const int firestoreEmulatorPort = 8080;
  static const String _configuredEmulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '',
  );

  static String get emulatorHost {
    if (_configuredEmulatorHost.isNotEmpty) {
      if (_configuredEmulatorHost != '127.0.0.1') {
        throw StateError(
          'FIREBASE_EMULATOR_HOST solo admite la interfaz local 127.0.0.1.',
        );
      }
      return _configuredEmulatorHost;
    }

    return defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : '127.0.0.1';
  }

  static void validateEnvironment() {
    validateUseEmulatorsValue(_useEmulatorsRaw);
  }

  @visibleForTesting
  static void validateUseEmulatorsValue(String value) {
    if (value != 'true' && value != 'false') {
      throw StateError(
        'USE_FIREBASE_EMULATORS solo admite los valores true o false.',
      );
    }
  }

  static Future<void> initialize() async {
    validateEnvironment();
    if (useEmulators && !kDebugMode) {
      throw StateError(
        'Los emuladores Firebase solo pueden utilizarse en modo debug.',
      );
    }

    final baseOptions = DefaultFirebaseOptions.currentPlatform;
    final options = useEmulators
        ? FirebaseOptions(
            apiKey: baseOptions.apiKey,
            appId: baseOptions.appId,
            messagingSenderId: baseOptions.messagingSenderId,
            projectId: emulatorProjectId,
            authDomain: baseOptions.authDomain,
            databaseURL: baseOptions.databaseURL,
            storageBucket: baseOptions.storageBucket,
            measurementId: baseOptions.measurementId,
            trackingId: baseOptions.trackingId,
            deepLinkURLScheme: baseOptions.deepLinkURLScheme,
            androidClientId: baseOptions.androidClientId,
            iosClientId: baseOptions.iosClientId,
            iosBundleId: baseOptions.iosBundleId,
            appGroupId: baseOptions.appGroupId,
          )
        : baseOptions;

    var app = await Firebase.initializeApp(options: options);

    // Android puede crear el app por defecto desde google-services.json antes
    // de que Dart se ejecute. En modo emulador lo reemplazamos para impedir que
    // Firestore conserve el projectId real aunque el host sea local.
    if (useEmulators && app.options.projectId != emulatorProjectId) {
      await app.delete();
      app = await Firebase.initializeApp(options: options);
    }

    if (useEmulators && app.options.projectId != emulatorProjectId) {
      throw StateError(
        'Firebase no pudo aislarse en el proyecto local de emulacion.',
      );
    }

    if (!useEmulators) return;

    final host = emulatorHost;
    await FirebaseAuth.instance.useAuthEmulator(
      host,
      authEmulatorPort,
      automaticHostMapping: false,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      host,
      firestoreEmulatorPort,
      automaticHostMapping: false,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );

    debugPrint(
      'Firebase Emulator Suite habilitada para ${app.options.projectId} '
      'en $host.',
    );
  }
}
