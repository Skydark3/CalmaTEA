import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../activities/config/activity_configuration_factory.dart';
import '../../../../activities/config/models/activity_configurations.dart';
import '../../../../activities/config/timer_configuration_utils.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/calmatea_button.dart';
import '../../../../../models/activity_model.dart';
import '../../../../../services/activity_service.dart';

class TimerConfigurationScreen extends StatefulWidget {
  final ActivityModel activity;
  final bool persistChanges;

  const TimerConfigurationScreen({
    super.key,
    required this.activity,
    this.persistChanges = true,
  });

  @override
  State<TimerConfigurationScreen> createState() =>
      _TimerConfigurationScreenState();
}

class _TimerConfigurationScreenState extends State<TimerConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _activityService = ActivityService();
  final _minutesController = TextEditingController();
  final _secondsController = TextEditingController();
  final _labelController = TextEditingController();

  String? _loadError;
  String? _submitError;
  bool _isLoading = false;

  bool get _hasValidType => widget.activity.type == ActivityType.timer;

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
      if (parsed != null && parsed is! TimerActivityConfig) {
        _loadError = 'La configuración no corresponde a un temporizador.';
        return;
      }
      if (parsed is TimerActivityConfig) {
        final duration = timerDurationParts(parsed.durationSeconds);
        _minutesController.text = duration.minutes.toString();
        _secondsController.text = duration.seconds.toString();
        _labelController.text = parsed.label ?? '';
      }
    } catch (error) {
      debugPrint('Error al cargar configuración de temporizador: $error');
      _loadError = 'No pudimos interpretar la configuración existente.';
    }
  }

  int? _parsePart(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? 0 : int.tryParse(normalized);
  }

  String? _validateMinutes(String? value) {
    final minutes = _parsePart(value ?? '');
    if (minutes == null || minutes < 0) return 'Ingresa minutos válidos';
    return null;
  }

  String? _validateSeconds(String? value) {
    final seconds = _parsePart(value ?? '');
    if (seconds == null || seconds < 0 || seconds > 59) {
      return 'Usa un valor entre 0 y 59';
    }
    return null;
  }

  Future<void> _save() async {
    if (_isLoading || !_hasValidType || _loadError != null) return;

    setState(() => _submitError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final minutes = _parsePart(_minutesController.text)!;
    final seconds = _parsePart(_secondsController.text)!;
    final durationSeconds = durationSecondsFromParts(
      minutes: minutes,
      seconds: seconds,
    );
    if (durationSeconds == null) {
      setState(() {
        _submitError = 'La duración total debe ser mayor que cero.';
      });
      return;
    }

    final timerConfig = TimerActivityConfig(
      durationSeconds: durationSeconds,
      label: normalizeTimerLabel(_labelController.text),
    );
    if (!timerConfig.isValid) {
      setState(() => _submitError = 'La duración ingresada no es válida.');
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
        configuration: timerConfig.toMap(),
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
      debugPrint('Error al guardar configuración de temporizador: $error');
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
    _minutesController.dispose();
    _secondsController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidType) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configurar temporizador')),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Esta pantalla solo permite configurar actividades con temporizador.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar temporizador')),
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
                      'Define la duración planificada para esta actividad.',
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
                Text(
                  'Duración',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minutesController,
                        enabled: !_isLoading,
                        validator: _validateMinutes,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Minutos',
                          hintText: '0',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _secondsController,
                        enabled: !_isLoading,
                        validator: _validateSeconds,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Segundos',
                          hintText: '0',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _labelController,
                  enabled: !_isLoading,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Etiqueta del temporizador (opcional)',
                    hintText: 'Ej.: Tiempo de respiración',
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
