import 'package:flutter/material.dart';

import '../../../../core/config/phase10_feature_flags.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/calmatea_button.dart';
import '../../../../models/child_model.dart';
import '../../../../models/therapy_model.dart';
import '../../../../services/child_service.dart';
import '../../../../services/therapy_service.dart';
import '../../therapies/presentation/create_therapy_screen.dart';
import '../../therapies/presentation/therapy_detail_screen.dart';
import '../../therapies/presentation/widgets/therapy_card.dart';
import 'edit_patient_screen.dart';
import 'patient_activity_history_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final ChildModel child;

  const PatientDetailScreen({super.key, required this.child});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final ChildService _childService = ChildService();
  final TherapyService _therapyService = TherapyService();
  late ChildModel _child;
  Stream<List<TherapyModel>>? _therapiesStream;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _child = widget.child;
    _therapiesStream = _createTherapiesStream();
  }

  Stream<List<TherapyModel>> _createTherapiesStream() {
    return _therapyService.watchTherapiesByChild(
      _child.id,
      _child.psychologistId,
    );
  }

  Stream<List<TherapyModel>> get _activeTherapiesStream {
    return _therapiesStream ??= _createTherapiesStream();
  }

  void _retryTherapies() {
    setState(() => _therapiesStream = _createTherapiesStream());
  }

  Future<void> _openEditPatient() async {
    final updatedChild = await Navigator.of(context).push<ChildModel>(
      MaterialPageRoute(builder: (_) => EditPatientScreen(child: _child)),
    );

    if (updatedChild == null || !mounted) return;
    setState(() => _child = updatedChild);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paciente actualizado correctamente'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _confirmDeletePatient() async {
    if (_isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar paciente'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este paciente? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isDeleting = true);

    try {
      await _childService.deleteChild(_child.id, _child.psychologistId);
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Paciente eliminado correctamente'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Error al eliminar paciente: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos eliminar al paciente. Inténtalo nuevamente.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openCreateTherapy() async {
    final wasCreated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreateTherapyScreen(child: _child)),
    );

    if (wasCreated != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Terapia asignada correctamente'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _openTherapyDetail(TherapyModel therapy) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TherapyDetailScreen(therapy: therapy, child: _child),
      ),
    );
  }

  void _openActivityHistory() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PatientActivityHistoryScreen(child: _child),
      ),
    );
  }

  Widget _buildAssignTherapyButton() {
    return SizedBox(
      width: double.infinity,
      child: CalmaTeaButton(
        text: 'Asignar terapia',
        icon: Icons.add_rounded,
        isOutlined: true,
        onPressed: _isDeleting ? null : _openCreateTherapy,
      ),
    );
  }

  Widget _buildTherapiesSection() {
    return StreamBuilder<List<TherapyModel>>(
      stream: _activeTherapiesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('No pudimos cargar las terapias.'),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _retryTherapies,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                  const SizedBox(height: 8),
                  _buildAssignTherapyButton(),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
          );
        }

        final therapies = snapshot.data ?? const <TherapyModel>[];
        if (therapies.isEmpty) {
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.psychology_outlined,
                        color: AppColors.mint,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Este paciente todavía no tiene terapias asignadas.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildAssignTherapyButton(),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            for (var index = 0; index < therapies.length; index++) ...[
              TherapyCard(
                therapy: therapies[index],
                onTap: () => _openTherapyDetail(therapies[index]),
              ),
              if (index < therapies.length - 1) const SizedBox(height: 10),
            ],
            const SizedBox(height: 16),
            _buildAssignTherapyButton(),
          ],
        );
      },
    );
  }

  String _formatBirthDate(DateTime date) {
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
    final trimmedName = _child.fullName.trim();
    final initial = trimmedName.isEmpty ? 'P' : trimmedName[0].toUpperCase();
    final notes = _child.notes?.trim();

    return PopScope(
      canPop: !_isDeleting,
      child: Scaffold(
        appBar: AppBar(title: const Text('Detalle del paciente')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: AppColors.primaryLight.withValues(
                        alpha: 0.25,
                      ),
                      foregroundColor: AppColors.primaryDark,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _child.fullName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_child.age} ${_child.age == 1 ? 'año' : 'años'}',
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mintLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _child.supportLevel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Información general',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.cake_outlined,
                        label: 'Fecha de nacimiento',
                        value: _formatBirthDate(_child.birthDate),
                      ),
                      const Divider(height: 28),
                      _InfoRow(
                        icon: Icons.support_outlined,
                        label: 'Nivel de apoyo',
                        value: _child.supportLevel,
                      ),
                      const Divider(height: 28),
                      _InfoRow(
                        icon: Icons.notes_rounded,
                        label: 'Notas',
                        value: notes == null || notes.isEmpty
                            ? 'No hay notas registradas'
                            : notes,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Terapias asignadas',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildTherapiesSection(),
              const SizedBox(height: 28),
              if (Phase10Features.executionHistoryEnabled) ...[
                SizedBox(
                  width: double.infinity,
                  child: CalmaTeaButton(
                    text: 'Historial de actividades',
                    icon: Icons.history_rounded,
                    isOutlined: true,
                    onPressed: _isDeleting ? null : _openActivityHistory,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: CalmaTeaButton(
                  text: 'Editar paciente',
                  icon: Icons.edit_outlined,
                  onPressed: _isDeleting ? null : _openEditPatient,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: CalmaTeaButton(
                  text: 'Eliminar paciente',
                  icon: Icons.delete_outline_rounded,
                  isOutlined: true,
                  isLoading: _isDeleting,
                  backgroundColor: AppColors.error,
                  textColor: AppColors.error,
                  onPressed: _confirmDeletePatient,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: AppColors.textPrimary, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
