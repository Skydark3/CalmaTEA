import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../activities/config/activity_configuration_factory.dart';
import '../../../../activities/config/drag_drop_configuration_utils.dart';
import '../../../../activities/config/models/activity_configurations.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/calmatea_button.dart';
import '../../../../../models/activity_model.dart';
import '../../../../../services/activity_service.dart';

class DragDropConfigurationScreen extends StatefulWidget {
  final ActivityModel activity;
  final bool persistChanges;

  const DragDropConfigurationScreen({
    super.key,
    required this.activity,
    this.persistChanges = true,
  });

  @override
  State<DragDropConfigurationScreen> createState() =>
      _DragDropConfigurationScreenState();
}

class _DragDropConfigurationScreenState
    extends State<DragDropConfigurationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _activityService = ActivityService();
  final List<_EditableDragDropTarget> _targets = [];
  final List<_EditableDragDropItem> _items = [];

  String? _loadError;
  String? _submitError;
  bool _isLoading = false;
  int _idCounter = 0;

  bool get _hasValidType => widget.activity.type == ActivityType.dragDrop;

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
      if (parsed != null && parsed is! DragDropActivityConfig) {
        _loadError = 'La configuración no corresponde a arrastrar y soltar.';
        return;
      }

      final config = parsed is DragDropActivityConfig ? parsed : null;
      final targetIds = <String>{};
      for (final target in config?.targets ?? const <DragDropTargetConfig>[]) {
        final candidateId = target.id.trim();
        final stableId = candidateId.isNotEmpty && targetIds.add(candidateId)
            ? candidateId
            : _generateId('target');
        targetIds.add(stableId);
        _targets.add(
          _EditableDragDropTarget(id: stableId, label: target.label),
        );
      }

      final itemIds = <String>{};
      for (final item in config?.items ?? const <DragDropItemConfig>[]) {
        final candidateId = item.id.trim();
        final stableId = candidateId.isNotEmpty && itemIds.add(candidateId)
            ? candidateId
            : _generateId('item');
        itemIds.add(stableId);
        _items.add(
          _EditableDragDropItem(
            id: stableId,
            label: item.label,
            targetId: item.targetId,
          ),
        );
      }
    } catch (error) {
      debugPrint('Error al cargar configuración drag and drop: $error');
      _loadError = 'No pudimos interpretar la configuración existente.';
    }
  }

  String _generateId(String prefix) {
    _idCounter += 1;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  void _addTarget() {
    if (_isLoading) return;
    setState(() {
      _targets.add(_EditableDragDropTarget(id: _generateId('target')));
      _submitError = null;
    });
  }

  void _removeTarget(int index) {
    if (_isLoading) return;
    final target = _targets[index];
    if (isDragDropTargetInUse(target.id, _draftItems())) {
      setState(() {
        _submitError =
            'No puedes eliminar un destino mientras tenga elementos asociados.';
      });
      return;
    }
    setState(() {
      final removed = _targets.removeAt(index);
      removed.dispose();
      _submitError = null;
    });
  }

  void _addItem() {
    if (_isLoading) return;
    if (_targets.isEmpty) {
      setState(() {
        _submitError = 'Agrega primero al menos una zona destino.';
      });
      return;
    }
    setState(() {
      _items.add(
        _EditableDragDropItem(
          id: _generateId('item'),
          targetId: _targets.first.id,
        ),
      );
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

  List<DragDropTargetConfig> _draftTargets() {
    return _targets
        .map(
          (target) => DragDropTargetConfig(
            id: target.id,
            label: target.labelController.text,
          ),
        )
        .toList(growable: false);
  }

  List<DragDropItemConfig> _draftItems() {
    return _items
        .map(
          (item) => DragDropItemConfig(
            id: item.id,
            label: item.labelController.text,
            targetId: item.targetId ?? '',
          ),
        )
        .toList(growable: false);
  }

  String? _validateLabel(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Este campo es obligatorio';
    return null;
  }

  String? _validateTarget(String? value) {
    if (value == null || !_targets.any((target) => target.id == value)) {
      return 'Selecciona un destino válido';
    }
    return null;
  }

  Future<void> _save() async {
    if (_isLoading || !_hasValidType || _loadError != null) return;

    setState(() => _submitError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final targets = prepareDragDropTargetsForSave(_draftTargets());
    final items = prepareDragDropItemsForSave(_draftItems());
    if (hasDuplicateDragDropTargetLabels(targets)) {
      setState(() => _submitError = 'Las zonas destino no pueden repetirse.');
      return;
    }
    if (hasDuplicateDragDropItemLabels(items)) {
      setState(() => _submitError = 'Los elementos no pueden repetirse.');
      return;
    }
    if (hasOrphanDragDropItems(items, targets)) {
      setState(() {
        _submitError = 'Cada elemento debe tener una zona destino válida.';
      });
      return;
    }

    final dragDropConfig = DragDropActivityConfig(
      items: items,
      targets: targets,
    );
    if (!dragDropConfig.isValid) {
      setState(() {
        _submitError = 'Agrega al menos un destino y un elemento válidos antes de guardar.';
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
        configuration: dragDropConfig.toMap(),
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
      debugPrint('Error al guardar configuración drag and drop: $error');
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
    for (final target in _targets) {
      target.dispose();
    }
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasValidType) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configurar arrastrar y soltar')),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Esta pantalla solo permite configurar actividades de arrastrar y soltar.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar arrastrar y soltar')),
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
                      'Relaciona cada elemento con su zona destino correcta.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (_loadError != null) ...[
                const SizedBox(height: 24),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ] else ...[
                const SizedBox(height: 24),
                Text(
                  'Zonas destino',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (_targets.isEmpty)
                  const Text(
                    'Todavía no hay zonas destino.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                for (final entry in _targets.indexed)
                  Card(
                    key: ValueKey(entry.$2.id),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: entry.$2.labelController,
                              enabled: !_isLoading,
                              validator: _validateLabel,
                              onChanged: (_) => setState(() {}),
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                labelText: 'Destino ${entry.$1 + 1}',
                                hintText: 'Ej.: Frutas',
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Eliminar destino',
                            onPressed: _isLoading
                                ? null
                                : () => _removeTarget(entry.$1),
                            color: AppColors.error,
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                CalmaTeaButton(
                  text: 'Agregar destino',
                  icon: Icons.add_rounded,
                  isOutlined: true,
                  onPressed: _addTarget,
                ),
                const SizedBox(height: 28),
                Text(
                  'Elementos arrastrables',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (_items.isEmpty)
                  const Text(
                    'Todavía no hay elementos.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                for (final entry in _items.indexed)
                  Card(
                    key: ValueKey(entry.$2.id),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: entry.$2.labelController,
                                  enabled: !_isLoading,
                                  validator: _validateLabel,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: InputDecoration(
                                    labelText: 'Elemento ${entry.$1 + 1}',
                                    hintText: 'Ej.: Manzana',
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Eliminar elemento',
                                onPressed: _isLoading
                                    ? null
                                    : () => _removeItem(entry.$1),
                                color: AppColors.error,
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue:
                                _targets.any(
                                  (target) => target.id == entry.$2.targetId,
                                )
                                ? entry.$2.targetId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Zona destino correcta',
                            ),
                            validator: _validateTarget,
                            items: _targets
                                .map(
                                  (target) => DropdownMenuItem(
                                    value: target.id,
                                    child: Text(
                                      target.labelController.text.trim().isEmpty
                                          ? 'Destino sin nombre'
                                          : target.labelController.text.trim(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: _isLoading
                                ? null
                                : (value) => entry.$2.targetId = value,
                          ),
                        ],
                      ),
                    ),
                  ),
                CalmaTeaButton(
                  text: 'Agregar elemento',
                  icon: Icons.add_rounded,
                  isOutlined: true,
                  onPressed: _addItem,
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
              const SizedBox(height: 16),
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

class _EditableDragDropTarget {
  final String id;
  final TextEditingController labelController;

  _EditableDragDropTarget({required this.id, String label = ''})
    : labelController = TextEditingController(text: label);

  void dispose() => labelController.dispose();
}

class _EditableDragDropItem {
  final String id;
  final TextEditingController labelController;
  String? targetId;

  _EditableDragDropItem({required this.id, String label = '', this.targetId})
    : labelController = TextEditingController(text: label);

  void dispose() => labelController.dispose();
}
