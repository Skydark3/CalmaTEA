import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../activities/config/activity_configuration_factory.dart';
import '../../../../activities/config/matching_configuration_utils.dart';
import '../../../../activities/config/models/activity_configurations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/calmatea_button.dart';
import '../../../../../models/activity_model.dart';
import '../../../../../services/activity_service.dart';

class MatchingConfigurationScreen extends StatefulWidget {
  final ActivityModel activity;
  final bool persistChanges;

  const MatchingConfigurationScreen({
    super.key,
    required this.activity,
    this.persistChanges = true,
  });

  @override
  State<MatchingConfigurationScreen> createState() =>
      _MatchingConfigurationScreenState();
}

class _MatchingConfigurationScreenState
    extends State<MatchingConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _activityService = ActivityService();
  final List<_EditableMatchingPair> _pairs = [];

  String? _loadError;
  String? _submitError;
  bool _isLoading = false;
  int _idCounter = 0;

  bool get _hasValidType => widget.activity.type == ActivityType.matching;

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
      if (parsed != null && parsed is! MatchingActivityConfig) {
        _loadError = 'La configuración no corresponde a un emparejamiento.';
        return;
      }

      final usedIds = <String>{};
      final existingPairs = parsed is MatchingActivityConfig
          ? parsed.pairs
          : const <MatchingPairConfig>[];
      for (final pair in existingPairs) {
        final candidateId = pair.id.trim();
        final stableId = candidateId.isNotEmpty && usedIds.add(candidateId)
            ? candidateId
            : _generatePairId();
        usedIds.add(stableId);
        _pairs.add(
          _EditableMatchingPair(
            id: stableId,
            left: pair.left,
            right: pair.right,
            leftResourceReference: pair.leftResourceReference,
            rightResourceReference: pair.rightResourceReference,
          ),
        );
      }
    } catch (error) {
      debugPrint('Error al cargar configuración de emparejamiento: $error');
      _loadError = 'No pudimos interpretar la configuración existente.';
    }
  }

  String _generatePairId() {
    _idCounter += 1;
    return 'pair_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  void _addPair() {
    if (_isLoading) return;
    setState(() {
      _pairs.add(_EditableMatchingPair(id: _generatePairId()));
      _submitError = null;
    });
  }

  void _removePair(int index) {
    if (_isLoading) return;
    setState(() {
      final removed = _pairs.removeAt(index);
      removed.dispose();
      _submitError = null;
    });
  }

  List<MatchingPairConfig> _draftPairs() {
    return _pairs
        .map(
          (pair) => MatchingPairConfig(
            id: pair.id,
            left: pair.leftController.text,
            right: pair.rightController.text,
            leftResourceReference: pair.leftResourceReference,
            rightResourceReference: pair.rightResourceReference,
          ),
        )
        .toList(growable: false);
  }

  String? _validateValue(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Este campo es obligatorio';
    return null;
  }

  Future<void> _save() async {
    if (_isLoading || !_hasValidType || _loadError != null) return;

    setState(() => _submitError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final pairs = prepareMatchingPairsForSave(_draftPairs());
    if (hasDuplicateMatchingPairs(pairs)) {
      setState(() {
        _submitError = 'No se puede guardar el mismo par más de una vez.';
      });
      return;
    }

    final matchingConfig = MatchingActivityConfig(pairs: pairs);
    if (!matchingConfig.isValid) {
      setState(() {
        _submitError = 'Agrega al menos un par válido antes de guardar.';
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
        configuration: matchingConfig.toMap(),
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
      debugPrint('Error al guardar configuración de emparejamiento: $error');
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
    for (final pair in _pairs) {
      pair.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidType) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configurar emparejamiento')),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Esta pantalla solo permite configurar actividades de emparejamiento.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar emparejamiento')),
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
                        'Define qué texto de la izquierda corresponde con el de la derecha.',
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
              else if (_pairs.isEmpty)
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Todavía no hay pares. Agrega el primero para configurar el emparejamiento.',
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
                    itemCount: _pairs.length,
                    itemBuilder: (context, index) {
                      final pair = _pairs[index];
                      return Card(
                        key: ValueKey(pair.id),
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
                                      'Par ${index + 1}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Eliminar par',
                                    onPressed: _isLoading
                                        ? null
                                        : () => _removePair(index),
                                    color: AppColors.error,
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              TextFormField(
                                controller: pair.leftController,
                                enabled: !_isLoading,
                                validator: _validateValue,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Texto izquierdo',
                                  hintText: 'Ej.: Perro',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: pair.rightController,
                                enabled: !_isLoading,
                                validator: _validateValue,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Texto correspondiente',
                                  hintText: 'Ej.: Animal',
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
                        text: 'Agregar par',
                        icon: Icons.add_rounded,
                        isOutlined: true,
                        onPressed: _loadError == null ? _addPair : null,
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

class _EditableMatchingPair {
  final String id;
  final String? leftResourceReference;
  final String? rightResourceReference;
  final TextEditingController leftController;
  final TextEditingController rightController;

  _EditableMatchingPair({
    required this.id,
    String left = '',
    String right = '',
    this.leftResourceReference,
    this.rightResourceReference,
  }) : leftController = TextEditingController(text: left),
       rightController = TextEditingController(text: right);

  void dispose() {
    leftController.dispose();
    rightController.dispose();
  }
}
