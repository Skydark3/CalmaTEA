import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/phase10_feature_flags.dart';
import '../../core/theme/app_colors.dart';
import '../activities/execution/activity_execution_router.dart';
import '../../models/activity_model.dart';
import '../../models/user_model.dart';
import 'activities/child_activities_screen.dart';
import 'activities/execution/activity_preview_router.dart';
import 'activities/execution/drag_drop_execution_screen.dart';
import 'activities/execution/emotion_execution_screen.dart';
import 'activities/execution/matching_execution_screen.dart';
import 'activities/execution/motor_execution_screen.dart';
import 'activities/execution/pictogram_execution_screen.dart';
import 'activities/execution/sequence_execution_screen.dart';
import 'activities/execution/timer_execution_screen.dart';
import 'activities/execution/tracing_execution_screen.dart';
import 'dashboard/child_home_screen.dart';
import 'profile/child_profile_screen.dart';

ActivityExecutionRouter buildChildActivityExecutionRouter({
  bool persistentExecutionEnabled = Phase10Features.activityExecutionEnabled,
  bool previewEnabled = Phase10Features.activityPreviewEnabled,
}) {
  if (kReleaseMode && previewEnabled) {
    return const ActivityExecutionRouter();
  }
  if (persistentExecutionEnabled == previewEnabled) {
    return const ActivityExecutionRouter();
  }

  if (previewEnabled) return buildActivityPreviewRouter();

  return ActivityExecutionRouter(
    mode: ActivityExecutionMode.persistent,
    handlers: {
      ActivityType.sequence: openSequenceExecution,
      ActivityType.dragDrop: openDragDropExecution,
      ActivityType.matching: openMatchingExecution,
      ActivityType.emotion: openEmotionExecution,
      ActivityType.pictogram: openPictogramExecution,
      ActivityType.timer: openTimerExecution,
      ActivityType.tracing: openTracingExecution,
      ActivityType.motor: openMotorExecution,
    },
  );
}

/// Navegación principal e independiente del área infantil.
class ChildShell extends StatefulWidget {
  final UserModel user;
  final Stream<List<ActivityModel>> activitiesStream;
  final Future<void> Function() onSignOut;
  final ActivityExecutionRouter? executionRouter;

  const ChildShell({
    super.key,
    required this.user,
    required this.activitiesStream,
    required this.onSignOut,
    this.executionRouter,
  });

  @override
  State<ChildShell> createState() => _ChildShellState();
}

class _ChildShellState extends State<ChildShell> {
  int _currentIndex = 0;
  late final ActivityExecutionRouter _executionRouter;

  @override
  void initState() {
    super.initState();
    _executionRouter =
        widget.executionRouter ?? buildChildActivityExecutionRouter();
  }

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      ChildHomeScreen(
        user: widget.user,
        onOpenActivities: () => _navigateToTab(1),
      ),
      ChildActivitiesScreen(
        activitiesStream: widget.activitiesStream,
        executionRouter: _executionRouter,
      ),
      ChildProfileScreen(user: widget.user, onSignOut: widget.onSignOut),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _navigateToTab,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.mintLight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.extension_outlined),
            selectedIcon: Icon(Icons.extension_rounded),
            label: 'Actividades',
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
