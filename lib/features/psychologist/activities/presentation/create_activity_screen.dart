import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/calmatea_button.dart';
import '../../../../core/widgets/calmatea_text_field.dart';
import '../../../activities/config/activity_configuration_summary.dart';
import '../../../../models/activity_model.dart';
import '../../../../models/child_model.dart';
import '../../../../models/therapy_model.dart';
import '../../../../services/activity_service.dart';
import '../configuration/activity_configuration_router.dart';

typedef ActivityCreator = Future<String> Function(ActivityModel activity);
typedef ActivityConfigurationOpener = Future<ActivityModel?> Function(
  BuildContext context,
  ActivityModel activity,
);
typedef PsychologistIdProvider = String? Function();
typedef ActivityIdProvider = String Function();

enum ActivityCreationStatus { configured }

class ActivityCreationResult {
  final ActivityModel activity;
  final ActivityCreationStatus status;

  const ActivityCreationResult({required this.activity, required this.status});

  bool get isConfigured => status == ActivityCreationStatus.configured;
}

class CreateActivityScreen extends StatefulWidget {
  final TherapyModel therapy;
  final ChildModel child;
  final ActivityCreator? activityCreator;
  final ActivityConfigurationOpener? configurationOpener;
  final PsychologistIdProvider? psychologistIdProvider;
  final ActivityIdProvider? activityIdProvider;

  const CreateActivityScreen({
    super.key,
    required this.therapy,
    required this.child,
    this.activityCreator,
    this.configurationOpener,
    this.psychologistIdProvider,
    this.activityIdProvider,
  });

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _difficultyController = TextEditingController(text: '1');
  final _instructionsController = TextEditingController();

  ActivityType? _activityType;
  String? _submitError;
  bool _isLoading = false;
  ActivityModel? _configuredDraft;

  bool get _hasConfiguredDraft => _configuredDraft != null;

  Future<String> _createActivity(ActivityModel activity) {
    final creator = widget.activityCreator;
    if (creator != null) return creator(activity);
    return ActivityService().createActivity(activity);
  }

  Future<ActivityModel?> _openConfiguration(ActivityModel activity) {
    final opener = widget.configurationOpener;
    if (opener != null) return opener(context, activity);
    return ActivityConfigurationRouter.open(
      context,
      activity,
      persistChanges: false,
    );
  }

  String _newActivityId() {
    return widget.activityIdProvider?.call() ??
        ActivityService().createActivityId();
  }

  String? _currentPsychologistId() {
    return widget.psychologistIdProvider?.call() ??
        FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _difficultyController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  String? _validateTitle(String? value) {
    final title = value?.trim() ?? '';
    if (title.length < 2) return 'Ingresa al menos 2 caracteres';
    if (title.length > 100) return 'El título no puede superar 100 caracteres';
    return null;
  }

  String? _validateDifficulty(String? value) {
    final difficulty = int.tryParse(value?.trim() ?? '');
    if (difficulty == null || difficulty < 1) {
      return 'Ingresa un número entero mayor que cero';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    final configuredDraft = _configuredDraft;
    if (configuredDraft != null) {
      await _saveConfiguredActivity(configuredDraft);
      return;
    }

    setState(() => _submitError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final psychologistId = _currentPsychologistId();
    final hasValidRelationship =
        psychologistId != null &&
        psychologistId == widget.therapy.psychologistId &&
        psychologistId == widget.child.psychologistId &&
        widget.child.id == widget.therapy.childId;

    if (!hasValidRelationship) {
      setState(() {
        _submitError = 'No se pudo identificar al profesional.';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final draft = ActivityModel(
        id: _newActivityId(),
        therapyId: widget.therapy.id,
        childId: widget.therapy.childId,
        psychologistId: psychologistId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _activityType!,
        difficulty: int.parse(_difficultyController.text.trim()),
        instructions: _instructionsController.text.trim(),
        configuration: const <String, dynamic>{},
        status: ActivityStatus.assigned,
        createdAt: DateTime.now(),
      );

      final configuredActivity = await _openConfiguration(draft);
      if (!mounted) return;

      if (configuredActivity == null) {
        setState(() {
          _isLoading = false;
          _submitError = 'La configuración fue cancelada. La actividad no se guardó ni se asignó.';
        });
        return;
      }

      final configurationStatus = ActivityConfigurationSummary.fromActivity(
        configuredActivity,
      ).status;
      if (configurationStatus != ActivityConfigurationStatus.configured) {
        setState(() {
          _isLoading = false;
          _submitError = 'Completa una configuración válida antes de guardar y asignar la actividad.';
        });
        return;
      }

      _configuredDraft = configuredActivity;
      await _saveConfiguredActivity(configuredActivity);
    } catch (error, stackTrace) {
      debugPrint('Error al preparar actividad: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _submitError =
            'No pudimos completar la configuración. La actividad no se guardó.';
      });
    }
  }

  Future<void> _saveConfiguredActivity(ActivityModel activity) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _submitError = null;
    });

    try {
      final activityId = await _createActivity(activity);
      if (!mounted) return;
      Navigator.of(context).pop(
        ActivityCreationResult(
          activity: activity.copyWith(id: activityId),
          status: ActivityCreationStatus.configured,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Error al guardar actividad configurada: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _submitError =
            'No pudimos guardar y asignar la actividad. Inténtalo nuevamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear actividad')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _ContextRow(
                      icon: Icons.psychology_outlined,
                      label: 'Terapia',
                      value: widget.therapy.name,
                    ),
                    const Divider(height: 24),
                    _ContextRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Paciente',
                      value: widget.child.fullName,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              CalmaTeaTextField(
                controller: _titleController,
                label: 'Título',
                hint: 'Ej. Reconocer emociones',
                prefixIcon: const Icon(Icons.title_rounded),
                enabled: !_isLoading && !_hasConfiguredDraft,
                validator: _validateTitle,
              ),
              const SizedBox(height: 18),
              CalmaTeaTextField(
                controller: _descriptionController,
                label: 'Descripción (opcional)',
                hint: 'Objetivo breve de la actividad',
                prefixIcon: const Icon(Icons.description_outlined),
                keyboardType: TextInputType.multiline,
                maxLines: 3,
                enabled: !_isLoading && !_hasConfiguredDraft,
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<ActivityType>(
                initialValue: _activityType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de actividad',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                isExpanded: true,
                items: ActivityType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(
                          type.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _isLoading || _hasConfiguredDraft
                    ? null
                    : (value) => setState(() => _activityType = value),
                validator: (value) =>
                    value == null ? 'Selecciona un tipo de actividad' : null,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _difficultyController,
                enabled: !_isLoading && !_hasConfiguredDraft,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validateDifficulty,
                decoration: const InputDecoration(
                  labelText: 'Dificultad',
                  hintText: 'Número entero',
                  prefixIcon: Icon(Icons.tune_rounded),
                ),
              ),
              const SizedBox(height: 18),
              CalmaTeaTextField(
                controller: _instructionsController,
                label: 'Instrucciones',
                hint: 'Indica qué debe realizar el paciente',
                prefixIcon: const Icon(Icons.list_alt_rounded),
                keyboardType: TextInputType.multiline,
                maxLines: 4,
                enabled: !_isLoading && !_hasConfiguredDraft,
              ),
              if (_submitError != null) ...[
                const SizedBox(height: 16),
                Text(
                  _submitError!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: CalmaTeaButton(
                  text: _hasConfiguredDraft
                      ? 'Reintentar guardar y asignar'
                      : 'Configurar actividad',
                  icon: _hasConfiguredDraft
                      ? Icons.cloud_upload_outlined
                      : Icons.tune_rounded,
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContextRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
