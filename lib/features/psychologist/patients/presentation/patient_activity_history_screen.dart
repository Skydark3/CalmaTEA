import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/phase10_feature_flags.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../models/activity_execution_session_model.dart';
import '../../../../models/child_model.dart';
import '../../../../models/patient_activity_history_model.dart';
import '../../../../services/patient_activity_history_service.dart';
import 'activity_execution_detail_screen.dart';

class PatientActivityHistoryScreen extends StatefulWidget {
  final ChildModel child;
  final PatientActivityHistoryDataSource? dataSource;
  final bool historyEnabled;

  const PatientActivityHistoryScreen({
    super.key,
    required this.child,
    this.dataSource,
    this.historyEnabled = Phase10Features.executionHistoryEnabled,
  });

  @override
  State<PatientActivityHistoryScreen> createState() =>
      _PatientActivityHistoryScreenState();
}

class _PatientActivityHistoryScreenState
    extends State<PatientActivityHistoryScreen> {
  PatientActivityHistoryDataSource? _dataSource;
  final List<PatientActivityHistoryEntry> _entries = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _accessDenied = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.historyEnabled) {
      _dataSource = widget.dataSource ?? PatientActivityHistoryService();
      _loadInitial();
    }
  }

  Future<void> _loadInitial() async {
    final dataSource = _dataSource;
    if (dataSource == null) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _accessDenied = false;
    });
    try {
      final page = await dataSource.loadFirstPage(child: widget.child);
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(page.entries)
          ..sort(
            (first, second) =>
                second.session.startedAt.compareTo(first.session.startedAt),
          );
        _hasMore = page.hasMore;
        _isLoading = false;
      });
    } on PatientActivityHistoryAccessDenied {
      if (!mounted) return;
      setState(() {
        _accessDenied = true;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error controlado al cargar historial: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final dataSource = _dataSource;
    if (dataSource == null || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await dataSource.loadNextPage(child: widget.child);
      if (!mounted) return;
      setState(() {
        final knownIds = _entries.map((entry) => entry.session.id).toSet();
        _entries.addAll(
          page.entries.where((entry) => knownIds.add(entry.session.id)),
        );
        _entries.sort(
          (first, second) =>
              second.session.startedAt.compareTo(first.session.startedAt),
        );
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Error controlado al paginar historial: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos cargar más registros. Inténtalo nuevamente.',
          ),
        ),
      );
    }
  }

  void _openDetail(PatientActivityHistoryEntry entry) {
    final dataSource = _dataSource;
    if (dataSource == null) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ActivityExecutionDetailScreen(
          child: widget.child,
          entry: entry,
          dataSource: dataSource,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!widget.historyEnabled) {
      return const EmptyState(
        icon: Icons.lock_clock_outlined,
        title: 'Historial no disponible',
        message: 'Esta función permanecerá deshabilitada hasta publicar y validar sus reglas de seguridad.',
      );
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_accessDenied) {
      return const EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Acceso denegado',
        message:
            'No tienes permiso para consultar el historial de este paciente.',
      );
    }
    if (_hasError) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'No pudimos cargar el historial',
        message: 'Comprueba la conexión e inténtalo nuevamente.',
        action: FilledButton.icon(
          onPressed: _loadInitial,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
        ),
      );
    }
    if (_entries.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'Sin ejecuciones',
        message: 'Aún no hay ejecuciones registradas para este paciente.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _entries.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == _entries.length) {
          if (!_hasMore) return const SizedBox.shrink();
          return Center(
            child: _isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : OutlinedButton.icon(
                    onPressed: _loadMore,
                    icon: const Icon(Icons.expand_more_rounded),
                    label: const Text('Cargar más'),
                  ),
          );
        }
        return _HistoryCard(
          entry: _entries[index],
          onTap: () => _openDetail(_entries[index]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de actividades')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                widget.child.fullName,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final PatientActivityHistoryEntry entry;
  final VoidCallback onTap;

  const _HistoryCard({required this.entry, required this.onTap});

  String _formatDateTime(DateTime value) {
    return DateFormat('dd/MM/yyyy, HH:mm').format(value.toLocal());
  }

  String _statusLabel(ActivityExecutionSessionStatus status) {
    return switch (status) {
      ActivityExecutionSessionStatus.inProgress => 'En progreso',
      ActivityExecutionSessionStatus.completed => 'Completada',
      ActivityExecutionSessionStatus.interrupted => 'Interrumpida',
    };
  }

  Color _statusColor(ActivityExecutionSessionStatus status) {
    return switch (status) {
      ActivityExecutionSessionStatus.inProgress => AppColors.warning,
      ActivityExecutionSessionStatus.completed => AppColors.success,
      ActivityExecutionSessionStatus.interrupted => AppColors.pending,
    };
  }

  @override
  Widget build(BuildContext context) {
    final session = entry.session;
    final statusColor = _statusColor(session.status);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                foregroundColor: AppColors.primaryDark,
                child: const Icon(Icons.extension_outlined),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.activity.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.activity.type.displayName,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 7),
                    Text('Inicio: ${_formatDateTime(session.startedAt)}'),
                    if (session.endedAt != null)
                      Text('Fin: ${_formatDateTime(session.endedAt!)}'),
                    const SizedBox(height: 8),
                    Text(
                      _statusLabel(session.status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
