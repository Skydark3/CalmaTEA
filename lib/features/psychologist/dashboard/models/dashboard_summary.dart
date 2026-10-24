class DashboardSummary {
  final int patientsCount;
  final int activeTherapiesCount;
  final int pendingActivitiesCount;

  const DashboardSummary({
    this.patientsCount = 0,
    this.activeTherapiesCount = 0,
    this.pendingActivitiesCount = 0,
  });

  /// Estado vacío reutilizable con todos los indicadores en 0.
  const DashboardSummary.empty()
      : patientsCount = 0,
        activeTherapiesCount = 0,
        pendingActivitiesCount = 0;

  DashboardSummary copyWith({
    int? patientsCount,
    int? activeTherapiesCount,
    int? pendingActivitiesCount,
  }) {
    return DashboardSummary(
      patientsCount: patientsCount ?? this.patientsCount,
      activeTherapiesCount: activeTherapiesCount ?? this.activeTherapiesCount,
      pendingActivitiesCount:
          pendingActivitiesCount ?? this.pendingActivitiesCount,
    );
  }
}
