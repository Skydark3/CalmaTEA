import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/phase10_feature_flags.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/child_model.dart';
import '../../../../models/user_model.dart';
import '../../../../services/activity_service.dart';
import '../../../../services/child_service.dart';
import '../../../../services/psychologist_execution_metrics_service.dart';
import '../../../../services/therapy_service.dart';
import '../models/dashboard_summary.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/execution_metrics_section.dart';
import 'widgets/patients_preview.dart';
import 'widgets/quick_action_card.dart';
import 'widgets/summary_card.dart';

/// Pantalla principal del Dashboard del Psicólogo (Pestaña "Inicio").
class PsychologistDashboardScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onNavigateToPatients;
  final VoidCallback onRegisterPatient;
  final bool isVisible;
  final bool executionMetricsEnabled;
  final PsychologistExecutionMetricsDataSource? executionMetricsDataSource;

  const PsychologistDashboardScreen({
    super.key,
    required this.user,
    required this.onNavigateToPatients,
    required this.onRegisterPatient,
    this.isVisible = true,
    this.executionMetricsEnabled = Phase10Features.executionMetricsEnabled,
    this.executionMetricsDataSource,
  });

  @override
  State<PsychologistDashboardScreen> createState() =>
      _PsychologistDashboardScreenState();
}

class _PsychologistDashboardScreenState
    extends State<PsychologistDashboardScreen> {
  final ActivityService _activityService = ActivityService();
  final ChildService _childService = ChildService();
  final TherapyService _therapyService = TherapyService();
  DashboardSummary _summary = const DashboardSummary.empty();
  List<ChildModel> _patients = const [];
  StreamSubscription<List<ChildModel>>? _childrenSubscription;
  StreamSubscription<int>? _activeTherapiesSubscription;
  StreamSubscription<int>? _pendingActivitiesSubscription;
  String? _patientsCountError;
  String? _activeTherapiesCountError;
  String? _pendingActivitiesCountError;

  @override
  void initState() {
    super.initState();
    _watchPatientsCount();
    _watchActiveTherapiesCount();
    _watchPendingActivitiesCount();
  }

  void _watchPendingActivitiesCount() {
    final psychologistId = FirebaseAuth.instance.currentUser?.uid;
    if (psychologistId == null) {
      _pendingActivitiesCountError =
          'No pudimos actualizar el total de actividades pendientes.';
      return;
    }

    _pendingActivitiesSubscription = _activityService
        .watchPendingActivitiesCountByPsychologist(psychologistId)
        .listen(
          (count) {
            if (!mounted) return;
            setState(() {
              _summary = _summary.copyWith(pendingActivitiesCount: count);
              _pendingActivitiesCountError = null;
            });
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Error al cargar actividades pendientes: $error');
            debugPrintStack(stackTrace: stackTrace);
            if (!mounted) return;
            setState(() {
              _pendingActivitiesCountError =
                  'No pudimos actualizar el total de actividades pendientes.';
            });
          },
        );
  }

  void _watchActiveTherapiesCount() {
    final psychologistId = FirebaseAuth.instance.currentUser?.uid;
    if (psychologistId == null) {
      _activeTherapiesCountError =
          'No pudimos actualizar el total de terapias activas.';
      return;
    }

    _activeTherapiesSubscription = _therapyService
        .watchActiveTherapiesCountByPsychologist(psychologistId)
        .listen(
          (count) {
            if (!mounted) return;
            setState(() {
              _summary = _summary.copyWith(activeTherapiesCount: count);
              _activeTherapiesCountError = null;
            });
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Error al cargar terapias activas: $error');
            debugPrintStack(stackTrace: stackTrace);
            if (!mounted) return;
            setState(() {
              _activeTherapiesCountError =
                  'No pudimos actualizar el total de terapias activas.';
            });
          },
        );
  }

  void _watchPatientsCount() {
    final psychologistId = FirebaseAuth.instance.currentUser?.uid;
    if (psychologistId == null) {
      _patientsCountError = 'No pudimos actualizar el total de pacientes.';
      return;
    }

    _childrenSubscription = _childService
        .watchChildren(psychologistId)
        .listen(
          (children) {
            if (!mounted) return;
            setState(() {
              _summary = _summary.copyWith(patientsCount: children.length);
              _patients = children;
              _patientsCountError = null;
            });
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Error al cargar el contador de pacientes: $error');
            debugPrintStack(stackTrace: stackTrace);
            if (!mounted) return;
            setState(() {
              _patientsCountError =
                  'No pudimos actualizar el total de pacientes.';
            });
          },
        );
  }

  @override
  void dispose() {
    _childrenSubscription?.cancel();
    _activeTherapiesSubscription?.cancel();
    _pendingActivitiesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Encabezado con saludo personalizado ────────────────
              DashboardHeader(user: widget.user),
              const SizedBox(height: 24),

              // ── Resumen de métricas principales ───────────────────
              Text(
                'Resumen general',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  // Adaptación responsiva (360-430 px)
                  return Row(
                    children: [
                      Expanded(
                        child: SummaryCard(
                          title: 'Pacientes',
                          count: _summary.patientsCount,
                          icon: Icons.people_outline_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SummaryCard(
                          title: 'Terapias activas',
                          count: _summary.activeTherapiesCount,
                          icon: Icons.psychology_outlined,
                          color: AppColors.mint,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SummaryCard(
                          title: 'Actividades pendientes',
                          count: _summary.pendingActivitiesCount,
                          icon: Icons.assignment_outlined,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (_patientsCountError != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _patientsCountError!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],
              if (_activeTherapiesCountError != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _activeTherapiesCountError!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],
              if (_pendingActivitiesCountError != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _pendingActivitiesCountError!,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 28),

              if (widget.executionMetricsEnabled) ...[
                ExecutionMetricsSection(
                  user: widget.user,
                  enabled: widget.executionMetricsEnabled,
                  isVisible: widget.isVisible,
                  dataSource: widget.executionMetricsDataSource,
                ),
                const SizedBox(height: 28),
              ],

              // ── Acciones Rápidas ──────────────────────────────────
              Text(
                'Acciones rápidas',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              QuickActionCard(
                title: 'Registrar paciente',
                subtitle: 'Añadir un nuevo niño o adolescente al seguimiento',
                icon: Icons.person_add_outlined,
                color: AppColors.primary,
                onTap: widget.onRegisterPatient,
              ),
              const SizedBox(height: 10),
              QuickActionCard(
                title: 'Ver pacientes',
                subtitle: 'Consultar el listado y fichas de seguimiento',
                icon: Icons.format_list_bulleted_rounded,
                color: AppColors.mint,
                onTap: widget.onNavigateToPatients,
              ),
              const SizedBox(height: 28),

              // ── Sección Mis Pacientes ─────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mis pacientes',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: widget.onNavigateToPatients,
                    child: const Text('Ver todos'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              PatientsPreview(
                patients: _patients.take(3).toList(growable: false),
                onRegisterPatient: widget.onRegisterPatient,
                onPatientDeleted: widget.onNavigateToPatients,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
