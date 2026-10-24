import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/calmatea_button.dart';
import '../../../../core/widgets/calmatea_text_field.dart';
import '../../../../models/child_model.dart';
import '../../../../services/child_service.dart';

class EditPatientScreen extends StatefulWidget {
  final ChildModel child;

  const EditPatientScreen({super.key, required this.child});

  @override
  State<EditPatientScreen> createState() => _EditPatientScreenState();
}

class _EditPatientScreenState extends State<EditPatientScreen> {
  static const _defaultSupportLevels = <String>[
    'Nivel 1 - Requiere apoyo',
    'Nivel 2 - Requiere apoyo sustancial',
    'Nivel 3 - Requiere apoyo muy sustancial',
  ];

  final _formKey = GlobalKey<FormState>();
  final _childService = ChildService();
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late final List<String> _supportLevels;

  late DateTime _birthDate;
  late String _supportLevel;
  String? _birthDateError;
  String? _submitError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.child.fullName);
    _notesController = TextEditingController(text: widget.child.notes ?? '');
    _birthDate = widget.child.birthDate;
    _supportLevel = widget.child.supportLevel;
    _supportLevels = [..._defaultSupportLevels];
    if (!_supportLevels.contains(_supportLevel)) {
      _supportLevels.add(_supportLevel);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(today.year - 30),
      lastDate: today,
      helpText: 'Selecciona la fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (selectedDate == null || !mounted) return;
    setState(() {
      _birthDate = selectedDate;
      _birthDateError = _validateBirthDate(selectedDate);
    });
  }

  String? _validateBirthDate(DateTime birthDate) {
    final age = _calculateAge(birthDate, DateTime.now());
    if (age < 8 || age > 18) {
      return 'El paciente debe tener entre 8 y 18 años';
    }
    return null;
  }

  int _calculateAge(DateTime birthDate, DateTime today) {
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  String? _validateName(String? value) {
    final validation = Validators.name(value);
    if (validation != null) return validation;
    if (value!.trim().length > 100) {
      return 'El nombre no puede superar 100 caracteres';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    final birthDateError = _validateBirthDate(_birthDate);
    setState(() {
      _birthDateError = birthDateError;
      _submitError = null;
    });

    if (!(_formKey.currentState?.validate() ?? false) ||
        birthDateError != null) {
      return;
    }

    if (FirebaseAuth.instance.currentUser?.uid != widget.child.psychologistId) {
      setState(() {
        _submitError =
            'No pudimos verificar tu sesión. Inicia sesión nuevamente.';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final notes = _notesController.text.trim();
      final updatedChild = ChildModel(
        id: widget.child.id,
        psychologistId: widget.child.psychologistId,
        fullName: _nameController.text.trim(),
        birthDate: _birthDate,
        supportLevel: _supportLevel,
        notes: notes.isEmpty ? null : notes,
        photoUrl: widget.child.photoUrl,
        createdAt: widget.child.createdAt,
        updatedAt: DateTime.now(),
      );

      await _childService.updateChild(updatedChild);
      if (!mounted) return;
      Navigator.of(context).pop(updatedChild);
    } catch (error, stackTrace) {
      debugPrint('Error al actualizar paciente: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _submitError =
            'No pudimos actualizar al paciente. Inténtalo nuevamente.';
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
      appBar: AppBar(title: const Text('Editar paciente')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Información del paciente',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Actualiza únicamente la información que necesites cambiar.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              CalmaTeaTextField(
                controller: _nameController,
                label: 'Nombre completo',
                hint: 'Nombre y apellidos',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                validator: _validateName,
                enabled: !_isLoading,
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 18),
              InkWell(
                onTap: _isLoading ? null : _selectBirthDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha de nacimiento',
                    errorText: _birthDateError,
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                  ),
                  child: Text(
                    _formatDate(_birthDate),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _supportLevel,
                decoration: const InputDecoration(
                  labelText: 'Nivel de apoyo',
                  prefixIcon: Icon(Icons.support_outlined),
                ),
                isExpanded: true,
                items: _supportLevels
                    .map(
                      (level) => DropdownMenuItem(
                        value: level,
                        child: Text(level, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _isLoading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _supportLevel = value);
                        }
                      },
                validator: (value) => value == null || value.isEmpty
                    ? 'Selecciona el nivel de apoyo'
                    : null,
              ),
              const SizedBox(height: 8),
              const Text(
                'Nivel de apoyo registrado por el profesional. CalmaTEA no lo determina.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 18),
              CalmaTeaTextField(
                controller: _notesController,
                label: 'Notas (opcional)',
                hint: 'Observaciones generales',
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
