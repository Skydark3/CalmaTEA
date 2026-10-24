import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/calmatea_button.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../models/child_model.dart';
import '../../../../services/child_service.dart';
import 'patient_detail_screen.dart';
import 'widgets/patient_card.dart';

class PatientsScreen extends StatefulWidget {
  final VoidCallback onRegisterPatient;

  const PatientsScreen({super.key, required this.onRegisterPatient});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final ChildService _childService = ChildService();
  late Stream<List<ChildModel>> _childrenStream;

  @override
  void initState() {
    super.initState();
    _childrenStream = _createChildrenStream();
  }

  Stream<List<ChildModel>> _createChildrenStream() {
    final psychologistId = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('psychologistId: $psychologistId');
    if (psychologistId == null) {
      return Stream<List<ChildModel>>.error(
        StateError('No hay un psicólogo autenticado.'),
      );
    }
    return _childService.watchChildren(psychologistId);
  }

  void _retry() {
    setState(() => _childrenStream = _createChildrenStream());
  }

  void _openPatientDetail(ChildModel child) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PatientDetailScreen(child: child)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis pacientes'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: widget.onRegisterPatient,
            tooltip: 'Registrar paciente',
            icon: const Icon(Icons.person_add_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<ChildModel>>(
        stream: _childrenStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorView(onRetry: _retry);
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }

          final patients = snapshot.data ?? const <ChildModel>[];
          if (patients.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'Todavía no tienes pacientes',
                  message: 'Registra tu primer paciente para comenzar el seguimiento terapéutico.',
                  action: CalmaTeaButton(
                    text: 'Registrar paciente',
                    icon: Icons.person_add_outlined,
                    onPressed: widget.onRegisterPatient,
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: patients.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final patient = patients[index];
              return PatientCard(
                patient: patient,
                onTap: () => _openPatientDetail(patient),
              );
            },
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'No pudimos cargar tus pacientes.',
          message: 'Revisa tu conexión e inténtalo nuevamente.',
          action: CalmaTeaButton(
            text: 'Reintentar',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ),
      ),
    );
  }
}
