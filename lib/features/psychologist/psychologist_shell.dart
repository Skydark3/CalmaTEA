import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import 'dashboard/presentation/psychologist_dashboard_screen.dart';
import 'patients/presentation/create_patient_screen.dart';
import 'patients/presentation/patients_screen.dart';
import 'profile/presentation/psychologist_profile_screen.dart';

/// Contenedor de navegación principal del área profesional (Fase 4).
class PsychologistShell extends StatefulWidget {
  final UserModel user;

  const PsychologistShell({super.key, required this.user});

  @override
  State<PsychologistShell> createState() => _PsychologistShellState();
}

class _PsychologistShellState extends State<PsychologistShell> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  Future<void> _openCreatePatient() async {
    final wasCreated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreatePatientScreen()),
    );

    if (wasCreated == true && mounted) {
      _navigateToTab(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paciente registrado correctamente'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      PsychologistDashboardScreen(
        user: widget.user,
        isVisible: _currentIndex == 0,
        onNavigateToPatients: () => _navigateToTab(1),
        onRegisterPatient: _openCreatePatient,
      ),
      PatientsScreen(onRegisterPatient: _openCreatePatient),
      PsychologistProfileScreen(user: widget.user),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _navigateToTab,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryLight.withValues(alpha: 0.25),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Pacientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
