import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../activities/config/activity_configuration_factory.dart';
import '../../../../activities/config/emotion_configuration_utils.dart';
import '../../../../activities/config/models/activity_configurations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/calmatea_button.dart';
import '../../../../../models/activity_model.dart';
import '../../../../../services/activity_service.dart';

class EmotionConfigurationScreen extends StatefulWidget {
  final ActivityModel activity;
  final bool persistChanges;

  const EmotionConfigurationScreen({
    super.key,
    required this.activity,
    this.persistChanges = true,
  });

  @override
  State<EmotionConfigurationScreen> createState() =>
      _EmotionConfigurationScreenState();
}

class _EmotionConfigurationScreenState
    extends State<EmotionConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _activityService = ActivityService();
  final List<_EditableEmotionOption> _options = [];

  String? _loadError;
  String? _submitError;
  bool _isLoading = false;
  int _idCounter = 0;

  bool get _hasValidType => widget.activity.type == ActivityType.emotion;

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
      if (parsed != null && parsed is! EmotionActivityConfig) {
        _loadError = 'La configuración no corresponde a emociones.';
        return;
      }

      final usedIds = <String>{};
      final existingOptions = parsed is EmotionActivityConfig
          ? parsed.options
          : const <EmotionOptionConfig>[];
      for (final option in existingOptions) {
        final candidateId = option.id.trim();
        final stableId = candidateId.isNotEmpty && usedIds.add(candidateId)
            ? candidateId
            : _generateOptionId();
        usedIds.add(stableId);
        _options.add(
          _EditableEmotionOption(
            id: stableId,
            label: option.label,
            prompt: option.prompt,
            expectedValue: option.expectedValue,
          ),
        );
      }
    } catch (error) {
      debugPrint('Error al cargar configuración de emociones: $error');
      _loadError = 'No pudimos interpretar la configuración existente.';
    }
  }

  String _generateOptionId() {
    _idCounter += 1;
    return 'emotion_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  void _addOption() {
    if (_isLoading) return;
    setState(() {
      _options.add(_EditableEmotionOption(id: _generateOptionId()));
      _submitError = null;
    });
  }

  void _removeOption(int index) {
    if (_isLoading) return;
    setState(() {
      final removed = _options.removeAt(index);
      removed.dispose();
      _submitError = null;
    });
  }

  List<EmotionOptionConfig> _draftOptions() {
    return _options
        .map(
          (option) => EmotionOptionConfig(
            id: option.id,
            label: option.labelController.text,
            prompt: option.promptController.text,
            expectedValue: option.expectedValueController.text,
          ),
        )
        .toList(growable: false);
  }

  String? _validateRequired(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Este campo es obligatorio';
    return null;
  }

  Future<void> _save() async {
    if (_isLoading || !_hasValidType || _loadError != null) return;

    setState(() => _submitError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final options = prepareEmotionOptionsForSave(_draftOptions());
    if (hasDuplicateEmotionOptions(options)) {
      setState(() {
        _submitError = 'No se puede guardar el mismo ejercicio más de una vez.';
      });
      return;
    }

    final emotionConfig = EmotionActivityConfig(options: options);
    if (!emotionConfig.isValid) {
      setState(() {
        _submitError = 'Agrega al menos un ejercicio válido antes de guardar.';
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
        configuration: emotionConfig.toMap(),
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
      debugPrint('Error al guardar configuración de emociones: $error');
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
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidType) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configurar emociones')),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Esta pantalla solo permite configurar actividades de emociones.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar emociones')),
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
                        'Crea ejercicios textuales para reconocer emociones en distintas situaciones.',
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
              else if (_options.isEmpty)
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Todavía no hay ejercicios. Agrega el primero para configurar la actividad.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: _options.length,
                    itemBuilder: (context, index) {
                      final option = _options[index];
                      return Card(
                        key: ValueKey(option.id),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Ejercicio ${index + 1}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Eliminar ejercicio',
                                    onPressed: _isLoading
                                        ? null
                                        : () => _removeOption(index),
                                    color: AppColors.error,
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              TextFormField(
                                controller: option.labelController,
                                enabled: !_isLoading,
                                validator: _validateRequired,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Emoción',
                                  hintText: 'Ej.: Felicidad',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: option.promptController,
                                enabled: !_isLoading,
                                validator: _validateRequired,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Situación o pregunta',
                                  hintText:
                                      'Describe el contexto del ejercicio',
                                  alignLabelWithHint: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: option.expectedValueController,
                                enabled: !_isLoading,
                                validator: _validateRequired,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Respuesta esperada',
                                  hintText: 'Escribe la respuesta correcta',
                                ),
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
                        text: 'Agregar ejercicio',
                        icon: Icons.add_rounded,
                        isOutlined: true,
                        onPressed: _loadError == null ? _addOption : null,
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

class _EditableEmotionOption {
  final String id;
  final TextEditingController labelController;
  final TextEditingController promptController;
  final TextEditingController expectedValueController;

  _EditableEmotionOption({
    required this.id,
    String label = '',
    String prompt = '',
    String expectedValue = '',
  }) : labelController = TextEditingController(text: label),
       promptController = TextEditingController(text: prompt),
       expectedValueController = TextEditingController(text: expectedValue);

  void dispose() {
    labelController.dispose();
    promptController.dispose();
    expectedValueController.dispose();
  }
}
