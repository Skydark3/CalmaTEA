import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/app_state.dart';
import '../../../core/models/activity_result.dart';
import 'activity_result_screen.dart';

/// Actividad: Memoria Visual — Pantalla 6 del mockup.
/// El usuario debe encontrar las parejas de tarjetas iguales.
class VisualMemoryScreen extends StatefulWidget {
  const VisualMemoryScreen({super.key});

  @override
  State<VisualMemoryScreen> createState() => _VisualMemoryScreenState();
}

class _VisualMemoryScreenState extends State<VisualMemoryScreen> {
  static const int _level = 1;
  static const int _totalPairs = 4;

  // Emojis para el nivel 1
  final List<String> _emojis = ['🚗', '🏠', '⭐', '🌸'];
  late List<String> _cards;
  late List<bool> _flipped;
  late List<bool> _matched;
  int? _firstFlipped;
  bool _canFlip = true;
  int _moves = 0;
  int _correctPairs = 0;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    _cards = [..._emojis, ..._emojis]..shuffle(Random());
    _flipped = List.filled(_cards.length, false);
    _matched = List.filled(_cards.length, false);
    _firstFlipped = null;
    _canFlip = true;
    _moves = 0;
    _correctPairs = 0;
    _stopwatch.reset();
    _stopwatch.start();
  }

  void _onCardTap(int index) {
    if (!_canFlip || _flipped[index] || _matched[index]) return;

    setState(() {
      _flipped[index] = true;
    });

    if (_firstFlipped == null) {
      _firstFlipped = index;
    } else {
      _moves++;
      _canFlip = false;

      if (_cards[_firstFlipped!] == _cards[index]) {
        // Par correcto
        setState(() {
          _matched[_firstFlipped!] = true;
          _matched[index] = true;
          _correctPairs++;
          _canFlip = true;
          _firstFlipped = null;
        });

        if (_correctPairs == _totalPairs) {
          _stopwatch.stop();
          _onGameComplete();
        }
      } else {
        // Par incorrecto — voltear de vuelta
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) {
            setState(() {
              _flipped[_firstFlipped!] = false;
              _flipped[index] = false;
              _canFlip = true;
              _firstFlipped = null;
            });
          }
        });
      }
    }
  }

  void _onGameComplete() {
    final result = ActivityResult(
      activityId: 'visual_memory',
      activityName: 'Memoria visual',
      totalQuestions: _totalPairs,
      correctAnswers: _correctPairs,
      wrongAnswers: _moves - _correctPairs,
      timeTaken: _stopwatch.elapsed,
      level: _level,
    );

    context.read<AppState>().addActivityResult(result);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityResultScreen(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Memoria visual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            Text('Nivel 1 • Encuentra las parejas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_outlined),
            onPressed: () {},
            tooltip: 'Leer instrucción',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Instrucción ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Toca las tarjetas y encuentra las parejas iguales',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ── Tablero 4x2 ──────────────────────────────────────
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _cards.length,
                itemBuilder: (ctx, i) => _CardTile(
                  emoji: _cards[i],
                  isFlipped: _flipped[i],
                  isMatched: _matched[i],
                  onTap: () => _onCardTap(i),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ── Contador de movimientos ──────────────────────────
            Text(
              'Movimientos: $_moves  •  Parejas: $_correctPairs / $_totalPairs',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            // ── Progreso ─────────────────────────────────────────
            LinearProgressIndicator(
              value: _correctPairs / _totalPairs,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: AppColors.success,
              backgroundColor: AppColors.cardBg,
            ),
            const SizedBox(height: 8),
            Text(
              '${((_correctPairs / _totalPairs) * 100).toStringAsFixed(0)}%  completado',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta del juego ────────────────────────────────────────────────────
class _CardTile extends StatelessWidget {
  final String emoji;
  final bool isFlipped;
  final bool isMatched;
  final VoidCallback onTap;

  const _CardTile({
    required this.emoji,
    required this.isFlipped,
    required this.isMatched,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isMatched
              ? AppColors.success.withValues(alpha: 0.15)
              : isFlipped
                  ? AppColors.cardBg
                  : AppColors.primary,
          borderRadius: BorderRadius.circular(14),
          border: isMatched
              ? Border.all(color: AppColors.success, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: isFlipped || isMatched
              ? Text(emoji, style: const TextStyle(fontSize: 32))
              : const Icon(Icons.star_outline, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
