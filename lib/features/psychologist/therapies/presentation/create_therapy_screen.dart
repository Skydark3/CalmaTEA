import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/calmatea_button.dart';
import '../../../../core/widgets/calmatea_text_field.dart';
import '../../../../models/child_model.dart';
import '../../../../models/therapy_date_utils.dart';
import '../../../../models/therapy_model.dart';
import '../../../../services/therapy_service.dart';

class CreateTherapyScreen extends StatefulWidget {
  final ChildModel child;

  const CreateTherapyScreen({super.key, required this.child});

  @override
  State<CreateTherapyScreen> createState() => _CreateTherapyScreenState();
}

class _CreateTherapyScreenState extends State<CreateTherapyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _therapyService = TherapyService();

  TherapyType? _therapyType;
  late DateTime _startDate;
  String? _startDateError;
  String? _submitError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startDate = normalizeTherapyDate(DateTime.now());
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
      initialDate: _startDate,
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

  Future<void> _submit() async {
    if (_isLoading) return;

    final dateError = _validateStartDate(_startDate);
    setState(() {
      _startDateError = dateError;
      _submitError = null;
    });

    if (!(_formKey.currentState?.validate() ?? false) || dateError != null) {
      return;
    }

    final psychologistId = FirebaseAuth.instance.currentUser?.uid;
    if (psychologistId == null ||
        psychologistId != widget.child.psychologistId) {
      setState(() {
        _submitError = 'No se pudo identificar al profesional.';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final notes = _notesController.text.trim();
      final therapy = TherapyModel(
        id: '',
        childId: widget.child.id,
        psychologistId: psychologistId,
        type: _therapyType!,
        status: TherapyStatus.active,
        startDate: _startDate,
        endDate: null,
        notes: notes.isEmpty ? null : notes,
        createdAt: DateTime.now(),
      );

      await _therapyService.createTherapy(therapy);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      debugPrint('Error al asignar terapia: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _submitError = 'No pudimos asignar la terapia. Inténtalo nuevamente.';
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
      appBar: AppBar(title: const Text('Asignar terapia')),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Paciente',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.child.fullName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
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
                    : (value) => setState(() => _therapyType = value),
                validator: (value) =>
                    value == null ? 'Selecciona un tipo de terapia' : null,
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
              const SizedBox(height: 18),
              CalmaTeaTextField(
                controller: _notesController,
                label: 'Notas (opcional)',
                hint: 'Objetivos iniciales u observaciones profesionales',
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
                  text: 'Asignar terapia',
                  icon: Icons.add_rounded,
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
