import 'package:flutter/material.dart';

import '../../../../core/widgets/calmatea_button.dart';
import '../../../../core/widgets/empty_state.dart';

/// Pantalla estructural para la pestaña "Pacientes" en Fase 4.
/// Muestra el estado vacío preparado para conectar el CRUD en Fase 5.
class PatientsPlaceholderScreen extends StatelessWidget {
  final VoidCallback onRegisterPatient;

  const PatientsPlaceholderScreen({super.key, required this.onRegisterPatient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis pacientes'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'Todavía no tienes pacientes registrados',
            message: 'Cuando registres un paciente, aparecerá aquí su seguimiento terapéutico, indicadores y actividades asignadas.',
            action: CalmaTeaButton(
              text: 'Registrar paciente',
              icon: Icons.person_add_outlined,
              onPressed: onRegisterPatient,
            ),
          ),
        ),
      ),
    );
  }
}
