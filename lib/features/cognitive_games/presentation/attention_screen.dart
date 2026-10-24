import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/app_state.dart';
import '../../../core/models/activity_result.dart';
import 'activity_result_screen.dart';

/// Actividad: Atención — Pantalla 9 del mockup.
/// El usuario debe encontrar la figura diferente en una cuadrícula.
class AttentionScreen extends StatefulWidget {
  const AttentionScreen({super.key});

  @override
  State<AttentionScreen> createState() => _AttentionScreenState();
}

class _AttentionScreenState extends State<AttentionScreen> {
  final List<_AttentionQuestion> _questions = [
    _AttentionQuestion(
      instruction: 'Encuentra la figura diferente',
      items: [
        _Shape(color: Colors.blue, shape: BoxShape.circle),
        _Shape(color: Colors.blue, shape: BoxShape.circle),
        _Shape(color: Colors.red, shape: BoxShape.circle),  // diferente
        _Shape(color: Colors.blue, shape: BoxShape.circle),
        _Shape(color: Colors.blue, shape: BoxShape.circle),
        _Shape(color: Colors.blue, shape: BoxShape.circle),
        _Shape(color: Colors.blue, shape: BoxShape.circle),
        _Shape(color: Colors.blue, shape: BoxShape.circle),
        _Shape(color: Colors.blue, shape: BoxShape.circle),
      ],
      differentIndex: 2,
    ),
    _AttentionQuestion(
      instruction: 'Encuentra la figura diferente',
      items: [
        _Shape(color: Colors.green, shape: BoxShape.circle),
        _Shape(color: Colors.green, shape: BoxShape.circle),
        _Shape(color: Colors.green, shape: BoxShape.circle),
        _Shape(color: Colors.green, shape: BoxShape.circle),
        _Shape(color: Colors.green, shape: BoxShape.rectangle), // diferente
        _Shape(color: Colors.green, shape: BoxShape.circle),
        _Shape(color: Colors.green, shape: BoxShape.circle),
        _Shape(color: Colors.green, shape: BoxShape.circle),
        _Shape(color: Colors.green, shape: BoxShape.circle),
      ],
      differentIndex: 4,
    ),
    _AttentionQuestion(
      instruction: 'Encuentra la figura diferente',
      items: [
        _Shape(color: Colors.orange, shape: BoxShape.rectangle),
        _Shape(color: Colors.orange, shape: BoxShape.rectangle),
        _Shape(color: Colors.orange, shape: BoxShape.rectangle),
        _Shape(color: Colors.purple, shape: BoxShape.rectangle), // diferente
        _Shape(color: Colors.orange, shape: BoxShape.rectangle),
        _Shape(color: Colors.orange, shape: BoxShape.rectangle),
        _Shape(color: Colors.orange, shape: BoxShape.rectangle),
        _Shape(color: Colors.orange, shape: BoxShape.rectangle),
        _Shape(color: Colors.orange, shape: BoxShape.rectangle),
      ],
      differentIndex: 3,
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
    final q = _questions[_currentIndex];
    setState(() {
      _selected = idx;
      _answered = true;
      if (idx == q.differentIndex) {
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
        activityId: 'attention',
        activityName: 'Atención',
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
            Text('Atención', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text('Atendro • Nivel 2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: AppColors.primary,
              backgroundColor: AppColors.cardBg,
            ),
            const SizedBox(height: 16),
            Text(
              q.instruction,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 32),
            // ── Cuadrícula 3x3 ───────────────────────────────────
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: q.items.length,
                itemBuilder: (ctx, i) {
                  Color borderColor = Colors.transparent;
                  if (_answered && i == q.differentIndex) {
                    borderColor = AppColors.success;
                  } else if (_answered && i == _selected && i != q.differentIndex) {
                    borderColor = AppColors.error;
                  }

                  return GestureDetector(
                    onTap: () => _onSelect(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        color: AppColors.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor, width: 3),
                      ),
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: q.items[i].color,
                            shape: q.items[i].shape,
                            borderRadius: q.items[i].shape == BoxShape.rectangle
                                ? BorderRadius.circular(6)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${_currentIndex + 1} / ${_questions.length}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
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

class _Shape {
  final Color color;
  final BoxShape shape;
  const _Shape({required this.color, required this.shape});
}

class _AttentionQuestion {
  final String instruction;
  final List<_Shape> items;
  final int differentIndex;
  const _AttentionQuestion({
    required this.instruction,
    required this.items,
    required this.differentIndex,
  });
}
