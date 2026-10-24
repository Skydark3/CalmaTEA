import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../activities/config/activity_configuration_factory.dart';
import '../../../../activities/config/models/activity_configurations.dart';
import '../../../../activities/config/motor_configuration_utils.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/calmatea_button.dart';
import '../../../../../models/activity_model.dart';
import '../../../../../services/activity_service.dart';

class MotorConfigurationScreen extends StatefulWidget {
  final ActivityModel activity;
  final bool persistChanges;

  const MotorConfigurationScreen({
    super.key,
    required this.activity,
    this.persistChanges = true,
  });

  @override
  State<MotorConfigurationScreen> createState() =>
      _MotorConfigurationScreenState();
}

class _MotorConfigurationScreenState extends State<MotorConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _activityService = ActivityService();
  final List<_EditableMotorStep> _steps = [];

  String? _loadError;
  String? _submitError;
  bool _isLoading = false;
  int _idCounter = 0;

  bool get _hasValidType => widget.activity.type == ActivityType.motor;

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
      if (parsed != null && parsed is! MotorActivityConfig) {
        _loadError = 'La configuración no corresponde a una actividad motora.';
        return;
      }

      final usedIds = <String>{};
      final existingSteps = parsed is MotorActivityConfig
          ? parsed.steps
          : const <MotorStepConfig>[];
      for (final step in existingSteps) {
        final candidateId = step.id.trim();
        final stableId = candidateId.isNotEmpty && usedIds.add(candidateId)
            ? candidateId
            : _generateStepId();
        usedIds.add(stableId);
        _steps.add(
          _EditableMotorStep(
            id: stableId,
            instruction: step.instruction,
            durationSeconds: step.durationSeconds,
            repetitions: step.repetitions,
          ),
        );
      }
    } catch (error) {
      debugPrint('Error al cargar configuración motora: $error');
      _loadError = 'No pudimos interpretar la configuración existente.';
    }
  }

  String _generateStepId() {
    _idCounter += 1;
    return 'motor_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  void _addStep() {
    if (_isLoading) return;
    setState(() {
      _steps.add(_EditableMotorStep(id: _generateStepId()));
      _submitError = null;
    });
  }

  void _removeStep(int index) {
    if (_isLoading) return;
    setState(() {
      final removed = _steps.removeAt(index);
      removed.dispose();
      _submitError = null;
    });
  }

  void _reorderSteps(int oldIndex, int newIndex) {
    if (_isLoading) return;
    final reordered = reorderMotorSteps(_draftSteps(), oldIndex, newIndex);
    final editorsById = {for (final step in _steps) step.id: step};
    setState(() {
      _steps
        ..clear()
        ..addAll(reordered.map((step) => editorsById[step.id]!));
      _submitError = null;
    });
  }

  List<MotorStepConfig> _draftSteps() {
    return _steps
        .map(
          (step) => MotorStepConfig(
            id: step.id,
            instruction: step.instructionController.text,
            durationSeconds: optionalPositiveIntFromInput(
              step.durationController.text,
            ),
            repetitions: optionalPositiveIntFromInput(
              step.repetitionsController.text,
            ),
          ),
        )
        .toList(growable: false);
  }

  String? _validateInstruction(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Escribe la instrucción';
    return null;
  }

  String? _validateOptionalPositiveInt(String? value) {
    if (!isValidOptionalPositiveIntInput(value ?? '')) {
      return 'Debe ser mayor que cero';
    }
    return null;
  }

  Future<void> _save() async {
    if (_isLoading || !_hasValidType || _loadError != null) return;

    setState(() => _submitError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final motorConfig = MotorActivityConfig(
      steps: prepareMotorStepsForSave(_draftSteps()),
    );
    if (!motorConfig.isValid) {
      setState(() {
        _submitError = 'Agrega al menos un paso válido antes de guardar.';
      });
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
        configuration: motorConfig.toMap(),
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
      debugPrint('Error al guardar configuración motora: $error');
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
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidType) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configurar actividad motora')),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Esta pantalla solo permite configurar actividades motoras.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar actividad motora')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Container(
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
                        'Define y ordena las instrucciones configuradas por el profesional.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              if (_loadError != null)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
                )
              else if (_steps.isEmpty)
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Todavía no hay pasos. Agrega el primero para configurar la actividad.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    buildDefaultDragHandles: false,
                    itemCount: _steps.length,
                    onReorderItem: _reorderSteps,
                    itemBuilder: (context, index) {
                      final step = _steps[index];
                      return Card(
                        key: ValueKey(step.id),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    enabled: !_isLoading,
                                    child: const Padding(
                                      padding: EdgeInsets.only(
                                        top: 14,
                                        right: 8,
                                      ),
                                      child: Icon(
                                        Icons.drag_handle_rounded,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      controller: step.instructionController,
                                      enabled: !_isLoading,
                                      validator: _validateInstruction,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      decoration: InputDecoration(
                                        labelText: 'Paso ${index + 1}',
                                        hintText: 'Describe la instrucción',
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Eliminar paso',
                                    onPressed: _isLoading
                                        ? null
                                        : () => _removeStep(index),
                                    color: AppColors.error,
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: step.durationController,
                                      enabled: !_isLoading,
                                      validator: _validateOptionalPositiveInt,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Duración (s)',
                                        hintText: 'Opcional',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: step.repetitionsController,
                                      enabled: !_isLoading,
                                      validator: _validateOptionalPositiveInt,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Repeticiones',
                                        hintText: 'Opcional',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: [
                    if (_submitError != null) ...[
                      Text(
                        _submitError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: CalmaTeaButton(
                        text: 'Agregar paso',
                        icon: Icons.add_rounded,
                        isOutlined: true,
                        onPressed: _loadError == null ? _addStep : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: CalmaTeaButton(
                        text: widget.persistChanges
                            ? 'Guardar configuración'
                            : 'Validar configuración',
                        icon: Icons.save_outlined,
                        isLoading: _isLoading,
                        onPressed: _loadError == null ? _save : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableMotorStep {
  final String id;
  final TextEditingController instructionController;
  final TextEditingController durationController;
  final TextEditingController repetitionsController;

  _EditableMotorStep({
    required this.id,
    String instruction = '',
    int? durationSeconds,
    int? repetitions,
  }) : instructionController = TextEditingController(text: instruction),
       durationController = TextEditingController(
         text: durationSeconds?.toString() ?? '',
       ),
       repetitionsController = TextEditingController(
         text: repetitions?.toString() ?? '',
       );

  void dispose() {
    instructionController.dispose();
    durationController.dispose();
    repetitionsController.dispose();
  }
}
