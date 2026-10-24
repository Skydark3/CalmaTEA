import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../activities/config/activity_configuration_factory.dart';
import '../../../../activities/config/models/activity_configurations.dart';
import '../../../../activities/config/tracing_configuration_utils.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/calmatea_button.dart';
import '../../../../../models/activity_model.dart';
import '../../../../../services/activity_service.dart';

class TracingConfigurationScreen extends StatefulWidget {
  final ActivityModel activity;
  final bool persistChanges;

  const TracingConfigurationScreen({
    super.key,
    required this.activity,
    this.persistChanges = true,
  });

  @override
  State<TracingConfigurationScreen> createState() =>
      _TracingConfigurationScreenState();
}

class _TracingConfigurationScreenState
    extends State<TracingConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _activityService = ActivityService();
  final _patternController = TextEditingController();
  final _valueController = TextEditingController();
  final _difficultyHintController = TextEditingController();

  String? _loadError;
  String? _submitError;
  bool _isLoading = false;

  bool get _hasValidType => widget.activity.type == ActivityType.tracing;

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  void _loadConfiguration() {
    if (!_hasValidType) return;

    try {
      final parsed = ActivityConfigurationFactory.fromMap(
        widget.activity.type,
        widget.activity.configuration,
      );
      if (parsed != null && parsed is! TracingActivityConfig) {
        _loadError =
            'La configuración no corresponde a una actividad de trazado.';
        return;
      }
      if (parsed is TracingActivityConfig) {
        _patternController.text = parsed.pattern;
        _valueController.text = parsed.value;
        _difficultyHintController.text = parsed.difficultyHint ?? '';
      }
    } catch (error) {
      debugPrint('Error al cargar configuración de trazado: $error');
      _loadError = 'No pudimos interpretar la configuración existente.';
    }
  }

  String? _validateRequired(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Este campo es obligatorio';
    return null;
  }

  Future<void> _save() async {
    if (_isLoading || !_hasValidType || _loadError != null) return;

    setState(() => _submitError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final tracingConfig = prepareTracingConfigurationForSave(
      pattern: _patternController.text,
      value: _valueController.text,
      difficultyHint: _difficultyHintController.text,
    );
    if (!tracingConfig.isValid) {
      setState(() => _submitError = 'La configuración ingresada no es válida.');
      return;
    }

    final psychologistId = FirebaseAuth.instance.currentUser?.uid;
    if (psychologistId == null ||
        psychologistId != widget.activity.psychologistId) {
      setState(() {
        _submitError = 'No se pudo identificar al profesional.';
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final activity = widget.activity;
      final updatedActivity = ActivityModel(
        id: activity.id,
        therapyId: activity.therapyId,
        childId: activity.childId,
        psychologistId: activity.psychologistId,
        title: activity.title,
        description: activity.description,
        type: activity.type,
        difficulty: activity.difficulty,
        instructions: activity.instructions,
        configuration: tracingConfig.toMap(),
        status: activity.status,
        createdAt: activity.createdAt,
        updatedAt: activity.updatedAt,
      );

      if (widget.persistChanges) {
        await _activityService.updateActivity(updatedActivity);
      }
      if (!mounted) return;
      Navigator.of(context).pop(updatedActivity);
    } catch (error, stackTrace) {
      debugPrint('Error al guardar configuración de trazado: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _submitError =
            'No pudimos guardar la configuración. Inténtalo nuevamente.';
      });
    }
  }

  @override
  void dispose() {
    _patternController.dispose();
    _valueController.dispose();
    _difficultyHintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidType) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configurar trazado')),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Esta pantalla solo permite configurar actividades de trazado.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar trazado')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.activity.title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Define de forma textual qué deberá trazarse.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_loadError != null)
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                )
              else ...[
                TextFormField(
                  controller: _patternController,
                  enabled: !_isLoading,
                  validator: _validateRequired,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de trazado',
                    hintText: 'Ej.: Letra, número o forma',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valueController,
                  enabled: !_isLoading,
                  validator: _validateRequired,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Valor a trazar',
                    hintText: 'Ej.: A, 1 o círculo',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _difficultyHintController,
                  enabled: !_isLoading,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Indicaciones de dificultad (opcional)',
                    hintText: 'Orientación adicional para el trazado',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
              if (_submitError != null) ...[
                const SizedBox(height: 16),
                Text(
                  _submitError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 24),
              CalmaTeaButton(
                text: widget.persistChanges
                    ? 'Guardar configuración'
                    : 'Validar configuración',
                icon: Icons.save_outlined,
                isLoading: _isLoading,
                onPressed: _loadError == null ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
