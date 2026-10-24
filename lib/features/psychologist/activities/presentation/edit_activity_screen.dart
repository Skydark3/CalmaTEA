import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/calmatea_button.dart';
import '../../../../core/widgets/calmatea_text_field.dart';
import '../../../../models/activity_model.dart';
import '../../../../models/child_model.dart';
import '../../../../models/therapy_model.dart';
import '../../../../services/activity_service.dart';

class EditActivityScreen extends StatefulWidget {
  final ActivityModel activity;
  final TherapyModel therapy;
  final ChildModel child;

  const EditActivityScreen({
    super.key,
    required this.activity,
    required this.therapy,
    required this.child,
  });

  @override
  State<EditActivityScreen> createState() => _EditActivityScreenState();
}

class _EditActivityScreenState extends State<EditActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _activityService = ActivityService();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _difficultyController;
  late final TextEditingController _instructionsController;

  late ActivityType _activityType;
  late ActivityStatus _status;
  String? _submitError;
  bool _isLoading = false;

  bool get _canChangeType => widget.activity.configuration.isEmpty;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.activity.title);
    _descriptionController = TextEditingController(
      text: widget.activity.description,
    );
    _difficultyController = TextEditingController(
      text: widget.activity.difficulty.toString(),
    );
    _instructionsController = TextEditingController(
      text: widget.activity.instructions,
    );
    _activityType = widget.activity.type;
    _status = widget.activity.status;
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

    setState(() => _submitError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final psychologistId = FirebaseAuth.instance.currentUser?.uid;
    final hasValidRelationship =
        psychologistId != null &&
        psychologistId == widget.activity.psychologistId &&
        psychologistId == widget.therapy.psychologistId &&
        psychologistId == widget.child.psychologistId &&
        widget.activity.therapyId == widget.therapy.id &&
        widget.activity.childId == widget.child.id &&
        widget.therapy.childId == widget.child.id;

    if (!hasValidRelationship) {
      setState(() {
        _submitError = 'No se pudo identificar al profesional.';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedActivity = ActivityModel(
        id: widget.activity.id,
        therapyId: widget.activity.therapyId,
        childId: widget.activity.childId,
        psychologistId: widget.activity.psychologistId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _activityType,
        difficulty: int.parse(_difficultyController.text.trim()),
        instructions: _instructionsController.text.trim(),
        configuration: widget.activity.configuration,
        status: _status,
        createdAt: widget.activity.createdAt,
        updatedAt: DateTime.now(),
      );

      await _activityService.updateActivity(updatedActivity);
      if (!mounted) return;
      Navigator.of(context).pop(updatedActivity);
    } catch (error, stackTrace) {
      debugPrint('Error al actualizar actividad: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _submitError =
            'No pudimos actualizar la actividad. Inténtalo nuevamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar actividad')),
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
                prefixIcon: const Icon(Icons.title_rounded),
                enabled: !_isLoading,
                validator: _validateTitle,
              ),
              const SizedBox(height: 18),
              CalmaTeaTextField(
                controller: _descriptionController,
                label: 'Descripción (opcional)',
                prefixIcon: const Icon(Icons.description_outlined),
                keyboardType: TextInputType.multiline,
                maxLines: 3,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<ActivityType>(
                initialValue: _activityType,
                decoration: InputDecoration(
                  labelText: 'Tipo de actividad',
                  prefixIcon: const Icon(Icons.category_outlined),
                  helperText: _canChangeType
                      ? null
                      : 'No puede cambiarse mientras exista configuración.',
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
                onChanged: _isLoading || !_canChangeType
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _activityType = value);
                      },
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _difficultyController,
                enabled: !_isLoading,
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
                prefixIcon: const Icon(Icons.list_alt_rounded),
                keyboardType: TextInputType.multiline,
                maxLines: 4,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<ActivityStatus>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  prefixIcon: Icon(Icons.info_outline_rounded),
                ),
                isExpanded: true,
                items: ActivityStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.displayName),
                      ),
                    )
                    .toList(),
                onChanged: _isLoading
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _status = value);
                      },
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
                  text: 'Guardar cambios',
                  icon: Icons.save_outlined,
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
