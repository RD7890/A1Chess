import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/common/eval.dart';
import 'package:lichess_mobile/src/model/over_the_board/move_grade.dart';
import 'package:lichess_mobile/src/model/over_the_board/otb_engine_controller.dart';

/// Collapsible Stockfish analysis panel for the OTB screen.
/// Shows top 3 engine lines, move grade badge, and a thinking progress bar.
class OtbAnalysisPanel extends ConsumerWidget {
  const OtbAnalysisPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(otbEngineControllerProvider);
    if (!engine.isEnabled) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(engine: engine),
          if (engine.isPanelVisible) _Body(engine: engine),
        ],
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  const _Header({required this.engine});
  final OtbEngineState engine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(otbEngineControllerProvider.notifier);
    return InkWell(
      onTap: ctrl.togglePanel,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            const Text(
              '♟ Stockfish',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            if (engine.isThinking)
              _ThinkingDots(),
            const Spacer(),
            if (engine.currentEval != null)
              _EvalBadge(eval: engine.currentEval!),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: ctrl.toggleEnabled,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  engine.isEnabled ? 'On' : 'Off',
                  style: TextStyle(
                    color: engine.isEnabled ? const Color(0xFF2ECC40) : Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              engine.isPanelVisible ? Icons.expand_more : Icons.expand_less,
              color: Colors.white38,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Body ────────────────────────────────────────────────────────────────────

class _Body extends ConsumerWidget {
  const _Body({required this.engine});
  final OtbEngineState engine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Move grade badge
          if (engine.lastMoveGrade != null) _MoveGradeBadge(grade: engine.lastMoveGrade!),
          // Engine lines
          if (engine.currentEval != null)
            _EngineLines(eval: engine.currentEval!)
          else if (engine.isThinking)
            _ThinkingPlaceholder(),
        ],
      ),
    );
  }
}

// ── Move grade badge ─────────────────────────────────────────────────────────

class _MoveGradeBadge extends StatelessWidget {
  const _MoveGradeBadge({required this.grade});
  final MoveGradeResult grade;

  String _fmt(String uci) {
    if (uci.length < 4) return uci;
    return '${uci.substring(0, 2)}→${uci.substring(2, 4)}'
        '${uci.length > 4 ? '=${uci[4].toUpperCase()}' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final g = grade.grade;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: g.color.withOpacity(0.08),
        border: Border.all(color: g.color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Text(
            g.label,
            style: TextStyle(color: g.color, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'You: ${_fmt(grade.playedUci)}',
                style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace'),
              ),
              if (grade.bestUci.isNotEmpty && grade.bestUci != grade.playedUci)
                Text(
                  'Best: ${_fmt(grade.bestUci)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Engine lines ─────────────────────────────────────────────────────────────

class _EngineLines extends StatelessWidget {
  const _EngineLines({required this.eval});
  final LocalEval eval;

  static const _dotColors = [Color(0xFF2ECC40), Color(0xFFFF9F1A), Color(0xFFE74C3C)];

  String _uci(String uci) {
    if (uci.length < 4) return uci;
    return '${uci.substring(0, 2)}→${uci.substring(2, 4)}';
  }

  String _pv(PvData pv, Position pos) {
    try {
      final buf = StringBuffer();
      int ply = pos.ply + 1;
      for (final san in pv.sanMoves(pos).take(5)) {
        if (ply.isOdd) buf.write('${(ply / 2).ceil()}. ');
        else if (buf.isEmpty) buf.write('${(ply / 2).ceil()}... ');
        buf.write('$san ');
        ply++;
      }
      return buf.toString().trim();
    } catch (_) {
      return pv.moves.take(5).join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pvs = eval.pvs.take(3).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < pvs.length; i++)
          _EngineRow(
            pv: pvs[i],
            position: eval.position,
            dotColor: _dotColors[min(i, 2)],
            uciLabel: pvs[i].moves.isNotEmpty ? _uci(pvs[i].moves[0]) : '—',
            pvLabel: _pv(pvs[i], eval.position),
          ),
      ],
    );
  }
}

class _EngineRow extends StatelessWidget {
  const _EngineRow({
    required this.pv,
    required this.position,
    required this.dotColor,
    required this.uciLabel,
    required this.pvLabel,
  });

  final PvData pv;
  final Position position;
  final Color dotColor;
  final String uciLabel;
  final String pvLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  uciLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
                if (pvLabel.isNotEmpty)
                  Text(
                    pvLabel,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            pv.evalString,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Eval badge ───────────────────────────────────────────────────────────────

class _EvalBadge extends StatelessWidget {
  const _EvalBadge({required this.eval});
  final LocalEval eval;

  @override
  Widget build(BuildContext context) {
    final cp = eval.cp;
    final mate = eval.mate;
    final isWhiteWinning = mate != null ? mate > 0 : (cp ?? 0) >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isWhiteWinning ? Colors.white : Colors.black,
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        eval.evalString,
        style: TextStyle(
          color: isWhiteWinning ? Colors.black : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ── Thinking indicators ───────────────────────────────────────────────────────

class _ThinkingDots extends StatefulWidget {
  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final dots = '.' * ((_ctrl.value * 4).floor() + 1);
        return Text(dots, style: const TextStyle(color: Color(0xFF2ECC40), fontSize: 13));
      },
    );
  }
}

class _ThinkingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(
          'Stockfish is thinking…',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ),
    );
  }
}
