import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/calmatea_button.dart';
import '../../../../core/widgets/calmatea_text_field.dart';
import '../../../../models/child_model.dart';
import '../../../../models/therapy_date_utils.dart';
import '../../../../models/therapy_model.dart';
import '../../../../services/therapy_service.dart';

class EditTherapyScreen extends StatefulWidget {
  final TherapyModel therapy;
  final ChildModel child;

  const EditTherapyScreen({
    super.key,
    required this.therapy,
    required this.child,
  });

  @override
  State<EditTherapyScreen> createState() => _EditTherapyScreenState();
}

class _EditTherapyScreenState extends State<EditTherapyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _therapyService = TherapyService();
  late final TextEditingController _notesController;

  late TherapyType _therapyType;
  late TherapyStatus _status;
  late DateTime _startDate;
  DateTime? _endDate;
  String? _startDateError;
  String? _endDateError;
  String? _submitError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _therapyType = widget.therapy.type;
    _status = widget.therapy.status;
    _startDate = normalizeTherapyDate(widget.therapy.startDate);
    _endDate = widget.therapy.endDate == null
        ? null
        : normalizeTherapyDate(widget.therapy.endDate!);
    if (_status == TherapyStatus.completed && _endDate == null) {
      _endDate = normalizeTherapyDate(DateTime.now());
    }
    _notesController = TextEditingController(text: widget.therapy.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final today = normalizeTherapyDate(DateTime.now());
    final firstDate = normalizeTherapyDate(widget.child.birthDate);
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: clampTherapyDate(
        _startDate,
        firstDate: firstDate,
        lastDate: today,
      ),
      firstDate: firstDate,
      lastDate: today,
      helpText: 'Selecciona la fecha de inicio',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (selectedDate == null || !mounted) return;
    setState(() {
      _startDate = normalizeTherapyDate(selectedDate);
      _startDateError = _validateStartDate(_startDate);
      _endDateError = _validateEndDate(_endDate);
    });
  }

  Future<void> _selectEndDate() async {
    final today = normalizeTherapyDate(DateTime.now());
    final firstDate = normalizeTherapyDate(_startDate);
    final currentEndDate = _endDate;
    final initialDate = clampTherapyDate(
      currentEndDate ?? firstDate,
      firstDate: firstDate,
      lastDate: today,
    );
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: today,
      helpText: 'Selecciona la fecha de finalización',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (selectedDate == null || !mounted) return;
    setState(() {
      _endDate = normalizeTherapyDate(selectedDate);
      _endDateError = _validateEndDate(_endDate);
    });
  }

  void _changeStatus(TherapyStatus? status) {
    if (status == null) return;
    setState(() {
      _status = status;
      if (status == TherapyStatus.completed) {
        _endDate ??= normalizeTherapyDate(DateTime.now());
        _endDateError = _validateEndDate(_endDate);
      } else {
        _endDate = null;
        _endDateError = null;
      }
    });
  }

  String? _validateStartDate(DateTime date) {
    final birthDate = normalizeTherapyDate(widget.child.birthDate);
    final today = normalizeTherapyDate(DateTime.now());
    if (!isTherapyDateInRange(date, firstDate: birthDate, lastDate: today)) {
      return 'Selecciona una fecha de inicio válida';
    }
    return null;
  }

  String? _validateEndDate(DateTime? date) {
    if (_status != TherapyStatus.completed) return null;
    if (date == null) return 'Selecciona la fecha de finalización';

    final startDate = normalizeTherapyDate(_startDate);
    final today = normalizeTherapyDate(DateTime.now());
    if (!isTherapyDateInRange(date, firstDate: startDate, lastDate: today)) {
      return 'La fecha debe estar entre el inicio y hoy';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    final startDateError = _validateStartDate(_startDate);
    final endDateError = _validateEndDate(_endDate);
    setState(() {
      _startDateError = startDateError;
      _endDateError = endDateError;
      _submitError = null;
    });

    if (!(_formKey.currentState?.validate() ?? false) ||
        startDateError != null ||
        endDateError != null) {
      return;
    }

    final psychologistId = FirebaseAuth.instance.currentUser?.uid;
    if (psychologistId != widget.therapy.psychologistId ||
        widget.child.id != widget.therapy.childId ||
        widget.child.psychologistId != widget.therapy.psychologistId) {
      setState(() {
        _submitError = 'No se pudo identificar al profesional.';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final notes = _notesController.text.trim();
      final updatedTherapy = TherapyModel(
        id: widget.therapy.id,
        childId: widget.therapy.childId,
        psychologistId: widget.therapy.psychologistId,
        type: _therapyType,
        status: _status,
        startDate: _startDate,
        endDate: _status == TherapyStatus.completed ? _endDate : null,
        notes: notes.isEmpty ? null : notes,
        createdAt: widget.therapy.createdAt,
        updatedAt: DateTime.now(),
      );

      await _therapyService.updateTherapy(updatedTherapy);
      if (!mounted) return;
      Navigator.of(context).pop(updatedTherapy);
    } catch (error, stackTrace) {
      debugPrint('Error al actualizar terapia: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _submitError =
            'No pudimos actualizar la terapia. Inténtalo nuevamente.';
      });
    }
  }

  String _formatDate(DateTime date) {
    const months = <String>[
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar terapia')),
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
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.child.fullName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<TherapyType>(
                initialValue: _therapyType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de terapia',
                  prefixIcon: Icon(Icons.psychology_outlined),
                ),
                isExpanded: true,
                items: TherapyType.values
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
                onChanged: _isLoading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _therapyType = value);
                        }
                      },
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<TherapyStatus>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  prefixIcon: Icon(Icons.info_outline_rounded),
                ),
                isExpanded: true,
                items: TherapyStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.displayName),
                      ),
                    )
                    .toList(),
                onChanged: _isLoading ? null : _changeStatus,
              ),
              const SizedBox(height: 18),
              InkWell(
                onTap: _isLoading ? null : _selectStartDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha de inicio',
                    errorText: _startDateError,
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                  ),
                  child: Text(
                    _formatDate(_startDate),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ),
              if (_status == TherapyStatus.completed) ...[
                const SizedBox(height: 18),
                InkWell(
                  onTap: _isLoading ? null : _selectEndDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Fecha de finalización',
                      errorText: _endDateError,
                      prefixIcon: const Icon(Icons.event_available_outlined),
                      suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                    ),
                    child: Text(
                      _endDate == null
                          ? 'Seleccionar fecha'
                          : _formatDate(_endDate!),
                      style: TextStyle(
                        color: _endDate == null
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              CalmaTeaTextField(
                controller: _notesController,
                label: 'Notas (opcional)',
                hint: 'Objetivos u observaciones profesionales',
                prefixIcon: const Icon(Icons.notes_rounded),
                maxLines: 4,
                enabled: !_isLoading,
                keyboardType: TextInputType.multiline,
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
