abstract final class ActivityExecutionUiText {
  static String saving({required bool previewMode}) =>
      previewMode ? 'Finalizando práctica...' : 'Guardando resultado...';

  static String saved({required bool previewMode}) => previewMode
      ? '¡Muy bien! Práctica completada. No se guardaron resultados.'
      : '¡Muy bien! Tu resultado fue guardado.';

  static String waitBeforeExit({required bool previewMode}) => previewMode
      ? 'Espera un momento, estamos finalizando.'
      : 'Espera un momento, estamos guardando.';

  static String completionFailure({required bool previewMode}) => previewMode
      ? 'No pudimos finalizar la práctica. Puedes reintentarlo.'
      : 'No pudimos guardar tu resultado. Puedes reintentarlo.';

  static String retryBeforeExit({required bool previewMode}) => previewMode
      ? 'Reintenta finalizar antes de salir de la actividad.'
      : 'Reintenta guardar antes de salir de la actividad.';

  static String retryLabel({required bool previewMode}) =>
      previewMode ? 'Reintentar' : 'Reintentar guardado';

  static String busyLabel({required bool previewMode}) =>
      previewMode ? 'Finalizando...' : 'Guardando...';
}
