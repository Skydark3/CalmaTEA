import 'package:flutter/material.dart';

import '../../../../../core/widgets/calmatea_button.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../models/child_model.dart';
import '../../../patients/presentation/patient_detail_screen.dart';

class PatientsPreview extends StatelessWidget {
  final List<ChildModel> patients;
  final VoidCallback onRegisterPatient;
  final VoidCallback onPatientDeleted;

  const PatientsPreview({
    super.key,
    this.patients = const [],
    required this.onRegisterPatient,
    required this.onPatientDeleted,
  });

  Future<void> _openPatientDetail(
    BuildContext context,
    ChildModel child,
  ) async {
    final wasDeleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PatientDetailScreen(child: child)),
    );
    if (wasDeleted == true) {
      onPatientDeleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (patients.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: EmptyState(
          icon: Icons.people_outline_rounded,
          title: 'Todavía no tienes pacientes',
          message: 'Registra tu primer paciente para comenzar el seguimiento terapéutico en CalmaTEA.',
          action: CalmaTeaButton(
            text: 'Registrar paciente',
            icon: Icons.person_add_outlined,
            onPressed: onRegisterPatient,
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: patients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final patient = patients[index];
        final trimmedName = patient.fullName.trim();
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                trimmedName.isNotEmpty ? trimmedName[0].toUpperCase() : 'P',
              ),
            ),
            title: Text(patient.fullName),
            subtitle: Text(
              '${patient.age} ${patient.age == 1 ? 'año' : 'años'}\n'
              'Nivel de apoyo: ${patient.supportLevel}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openPatientDetail(context, patient),
          ),
        );
      },
    );
  }
}
