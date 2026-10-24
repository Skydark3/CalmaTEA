import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tea_app/features/auth/presentation/auth_gate.dart';
import 'package:tea_app/models/user_model.dart';

void main() {
  UserModel user({required UserRole role, String? childId}) => UserModel(
    id: '${role.name}-uid',
    name: role == UserRole.child ? 'Paciente' : 'Profesional',
    email: '${role.name}@example.test',
    role: role,
    childId: childId,
    createdAt: DateTime(2026),
  );

  Widget subject({
    required UserProfileLoader loader,
    Duration timeout = const Duration(seconds: 1),
  }) {
    return MaterialApp(
      home: UserProfileResolver(
        uid: 'auth-uid',
        profileLoader: loader,
        profileTimeout: timeout,
        onSignOut: () async {},
        childActivitiesStream: Stream.value(const []),
        authenticatedShellBuilder: (profile) =>
            Scaffold(body: Text('shell-${profile.role.name}')),
      ),
    );
  }

  testWidgets('restaura perfil profesional y construye su shell', (
    tester,
  ) async {
    final pendingProfile = Completer<UserModel?>();
    await tester.pumpWidget(subject(loader: (_) => pendingProfile.future));

    expect(find.text('Cargando perfil...'), findsOneWidget);

    pendingProfile.complete(user(role: UserRole.psychologist));
    await tester.pumpAndSettle();

    expect(find.text('shell-psychologist'), findsOneWidget);
    expect(find.text('Cargando perfil...'), findsNothing);
  });

  testWidgets('restaura perfil infantil vinculado y construye su shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        loader: (_) async =>
            user(role: UserRole.child, childId: 'child-document-id'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('shell-child'), findsOneWidget);
  });

  testWidgets('perfil infantil sin vínculo permanece bloqueado', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(loader: (_) async => user(role: UserRole.child)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cuenta sin vinculación'), findsOneWidget);
    expect(find.text('shell-child'), findsNothing);
  });

  testWidgets('timeout reemplaza la carga por un error controlado', (
    tester,
  ) async {
    final neverCompletes = Completer<UserModel?>();
    await tester.pumpWidget(
      subject(
        loader: (_) => neverCompletes.future,
        timeout: const Duration(milliseconds: 20),
      ),
    );

    await tester.pump(const Duration(milliseconds: 25));

    expect(find.text('Cargando perfil...'), findsNothing);
    expect(find.text('No pudimos conectar con tu perfil'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('Firestore unavailable permite reintentar sin spinner infinito', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      subject(
        loader: (_) async {
          attempts++;
          if (attempts == 1) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'unavailable',
            );
          }
          return user(role: UserRole.psychologist);
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No pudimos conectar con tu perfil'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('shell-psychologist'), findsOneWidget);
  });
}
