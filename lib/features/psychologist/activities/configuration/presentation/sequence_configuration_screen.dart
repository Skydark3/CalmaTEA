import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../activities/config/activity_configuration_factory.dart';
import '../../../../activities/config/models/activity_configurations.dart';
import '../../../../activities/config/sequence_configuration_utils.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/calmatea_button.dart';
import '../../../../../models/activity_model.dart';
import '../../../../../services/activity_service.dart';

class SequenceConfigurationScreen extends StatefulWidget {
  final ActivityModel activity;
  final bool persistChanges;

  const SequenceConfigurationScreen({
    super.key,
    required this.activity,
    this.persistChanges = true,
  });

  @override
  State<SequenceConfigurationScreen> createState() =>
      _SequenceConfigurationScreenState();
}

class _SequenceConfigurationScreenState
    extends State<SequenceConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _activityService = ActivityService();
  final List<_EditableSequenceItem> _items = [];

  String? _loadError;
  String? _submitError;
  bool _isLoading = false;
  int _idCounter = 0;

  bool get _hasValidType => widget.activity.type == ActivityType.sequence;

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
      if (parsed != null && parsed is! SequenceActivityConfig) {
        _loadError = 'La configuración no corresponde a una secuencia.';
        return;
      }

      final existingItems = parsed is SequenceActivityConfig
          ? List<SequenceItemConfig>.of(parsed.items)
          : <SequenceItemConfig>[];
      existingItems.sort(
        (first, second) => first.order.compareTo(second.order),
      );

      final usedIds = <String>{};
      for (final item in existingItems) {
        final stableId = item.id.trim().isNotEmpty && usedIds.add(item.id)
            ? item.id
            : _generateItemId();
        usedIds.add(stableId);
        _items.add(
          _EditableSequenceItem(
            id: stableId,
            label: item.label,
            visualReference: item.visualReference,
          ),
        );
      }
    } catch (error) {
      debugPrint('Error al cargar configuración de secuencia: $error');
      _loadError = 'No pudimos interpretar la configuración existente.';
    }
  }

  String _generateItemId() {
    _idCounter += 1;
    return 'step_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  void _addItem() {
    if (_isLoading) return;
    setState(() {
      _items.add(_EditableSequenceItem(id: _generateItemId()));
      _submitError = null;
    });
  }

  void _removeItem(int index) {
    if (_isLoading) return;
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
      _submitError = null;
    });
  }

  void _reorderItems(int oldIndex, int newIndex) {
    if (_isLoading) return;
    final reordered = reorderSequenceItems(_draftItems(), oldIndex, newIndex);
    final editorsById = {for (final item in _items) item.id: item};
    setState(() {
      _items
        ..clear()
        ..addAll(reordered.map((item) => editorsById[item.id]!));
      _submitError = null;
    });
  }

  List<SequenceItemConfig> _draftItems() {
    return _items.indexed
        .map(
          (entry) => SequenceItemConfig(
            id: entry.$2.id,
            label: entry.$2.controller.text,
            order: entry.$1,
            visualReference: entry.$2.visualReference,
          ),
        )
        .toList(growable: false);
  }

  String? _validateLabel(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Escribe el texto del paso';
    return null;
  }

  Future<void> _save() async {
    if (_isLoading || !_hasValidType || _loadError != null) return;

    setState(() => _submitError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final sequenceConfig = SequenceActivityConfig(
      items: prepareSequenceItemsForSave(_draftItems()),
    );
    if (!sequenceConfig.isValid) {
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
        configuration: sequenceConfig.toMap(),
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
      debugPrint('Error al guardar configuración de secuencia: $error');
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
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidType) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configurar secuencia')),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Esta pantalla solo permite configurar actividades de secuencia.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar secuencia')),
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
                        'Ordena los pasos en la secuencia correcta.',
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
              else if (_items.isEmpty)
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Todavía no hay pasos. Agrega el primero para configurar la secuencia.',
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
                    itemCount: _items.length,
                    onReorderItem: _reorderItems,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        key: ValueKey(item.id),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ReorderableDragStartListener(
                                index: index,
                                enabled: !_isLoading,
                                child: const Padding(
                                  padding: EdgeInsets.only(top: 14, right: 8),
                                  child: Icon(
                                    Icons.drag_handle_rounded,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextFormField(
                                  controller: item.controller,
                                  enabled: !_isLoading,
                                  validator: _validateLabel,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: InputDecoration(
                                    labelText: 'Paso ${index + 1}',
                                    hintText: 'Describe este paso',
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Eliminar paso',
                                onPressed: _isLoading
                                    ? null
                                    : () => _removeItem(index),
                                color: AppColors.error,
                                icon: const Icon(Icons.delete_outline_rounded),
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
                        onPressed: _loadError == null ? _addItem : null,
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

class _EditableSequenceItem {
  final String id;
  final String? visualReference;
  final TextEditingController controller;

  _EditableSequenceItem({
    required this.id,
    String label = '',
    this.visualReference,
  }) : controller = TextEditingController(text: label);

  void dispose() => controller.dispose();
}
