import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/app_state.dart';
import '../../../core/models/activity_result.dart';
import 'activity_result_screen.dart';

/// Actividad: Asociación — Pantalla 8 del mockup.
/// El usuario selecciona qué objeto corresponde a la pregunta.
class AssociationScreen extends StatefulWidget {
  const AssociationScreen({super.key});

  @override
  State<AssociationScreen> createState() => _AssociationScreenState();
}

class _AssociationScreenState extends State<AssociationScreen> {
  final List<_Question> _questions = [
    _Question(
      prompt: '¿Qué se usa para comer?',
      options: ['🥄', '🐻', '🚗', '📚'],
      correctIndex: 0,
    ),
    _Question(
      prompt: '¿Qué sirve para dormir?',
      options: ['🛏️', '🚿', '🍎', '🎵'],
      correctIndex: 0,
    ),
    _Question(
      prompt: '¿Qué sirve para bañarse?',
      options: ['🚗', '🛁', '📞', '🌸'],
      correctIndex: 1,
    ),
    _Question(
      prompt: '¿Qué se usa para leer?',
      options: ['🏀', '📖', '🧃', '🎨'],
      correctIndex: 1,
    ),
    _Question(
      prompt: '¿Qué animal hace "guau"?',
      options: ['🐱', '🐟', '🐶', '🐦'],
      correctIndex: 2,
    ),
  ];

  int _currentIndex = 0;
  int _correct = 0;
  int _wrong = 0;
  int? _selected;
  bool _answered = false;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
  }

  void _onSelect(int idx) {
    if (_answered) return;
    setState(() {
      _selected = idx;
      _answered = true;
      if (idx == _questions[_currentIndex].correctIndex) {
        _correct++;
      } else {
        _wrong++;
      }
    });
  }

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selected = null;
        _answered = false;
      });
    } else {
      _stopwatch.stop();
      final result = ActivityResult(
        activityId: 'association',
        activityName: 'Asociación',
        totalQuestions: _questions.length,
        correctAnswers: _correct,
        wrongAnswers: _wrong,
        timeTaken: _stopwatch.elapsed,
        level: 2,
      );
      context.read<AppState>().addActivityResult(result);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ActivityResultScreen(result: result)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Asociación', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text('Mejora tu memoria \u2022 Nivel 2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Progreso ─────────────────────────────────────────
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: AppColors.primary,
              backgroundColor: AppColors.cardBg,
            ),
            const SizedBox(height: 8),
            Text(
              '${_currentIndex + 1} / ${_questions.length}',
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            // ── Pregunta ─────────────────────────────────────────
            Text(
              q.prompt,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 40),
            // ── Opciones (2x2) ───────────────────────────────────
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: q.options.length,
                itemBuilder: (ctx, i) {
                  Color borderColor = AppColors.cardBg;
                  Color bgColor = AppColors.cardBg;

                  if (_answered) {
                    if (i == q.correctIndex) {
                      borderColor = AppColors.success;
                      bgColor = AppColors.success.withValues(alpha: 0.12);
                    } else if (i == _selected) {
                      borderColor = AppColors.error;
                      bgColor = AppColors.error.withValues(alpha: 0.12);
                    }
                  } else if (_selected == i) {
                    borderColor = AppColors.primary;
                    bgColor = AppColors.primaryLight.withValues(alpha: 0.2);
                  }

                  return GestureDetector(
                    onTap: () => _onSelect(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor, width: 2.5),
                      ),
                      child: Center(
                        child: Text(
                          q.options[i],
                          style: const TextStyle(fontSize: 52),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // ── Botón Siguiente ──────────────────────────────────
            if (_answered)
              ElevatedButton(
                onPressed: _next,
                child: Text(
                  _currentIndex < _questions.length - 1
                      ? 'Siguiente'
                      : 'Ver resultado',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Question {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  const _Question({
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });
}
