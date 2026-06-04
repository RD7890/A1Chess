import 'dart:async';
import 'dart:math';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/common/eval.dart';
import 'package:lichess_mobile/src/model/common/id.dart';
import 'package:lichess_mobile/src/model/engine/engine.dart';
import 'package:lichess_mobile/src/model/engine/evaluation_service.dart';
import 'package:lichess_mobile/src/model/engine/work.dart';
import 'package:lichess_mobile/src/model/over_the_board/move_grade.dart';
import 'package:lichess_mobile/src/model/over_the_board/over_the_board_game_controller.dart';
import 'package:multistockfish/multistockfish.dart';

/// Engine analysis state for an Over-The-Board game.
class OtbEngineState {
  const OtbEngineState({
    this.currentEval,
    this.lastMoveGrade,
    this.isEnabled = true,
    this.isPanelVisible = true,
    this.isThinking = false,
  });

  final LocalEval? currentEval;
  final MoveGradeResult? lastMoveGrade;
  final bool isEnabled;
  final bool isPanelVisible;
  final bool isThinking;

  OtbEngineState copyWith({
    LocalEval? Function()? currentEval,
    MoveGradeResult? Function()? lastMoveGrade,
    bool? isEnabled,
    bool? isPanelVisible,
    bool? isThinking,
  }) =>
      OtbEngineState(
        currentEval: currentEval != null ? currentEval() : this.currentEval,
        lastMoveGrade: lastMoveGrade != null ? lastMoveGrade() : this.lastMoveGrade,
        isEnabled: isEnabled ?? this.isEnabled,
        isPanelVisible: isPanelVisible ?? this.isPanelVisible,
        isThinking: isThinking ?? this.isThinking,
      );

  /// Arrow shapes derived from top engine PVs (green → orange → red).
  ISet<Shape> get shapes {
    final eval = currentEval;
    if (eval == null || !isEnabled) return ISet();
    const brushColors = [Color(0xFF2ECC40), Color(0xFFFF9F1A), Color(0xFFE74C3C)];
    final arrows = <Shape>[];
    for (var i = 0; i < min(3, eval.pvs.length); i++) {
      final pv = eval.pvs[i];
      if (pv.moves.isEmpty) continue;
      final move = Move.parse(pv.moves[0]);
      if (move == null) continue;
      switch (move) {
        case NormalMove(:final from, :final to):
          arrows.add(
            Arrow(
              orig: from,
              dest: to,
              scale: i == 0 ? 1.0 : 0.82,
              color: brushColors[i],
            ),
          );
        default:
          break;
      }
    }
    return ISet(arrows);
  }
}

final otbEngineControllerProvider =
    NotifierProvider.autoDispose<OtbEngineController, OtbEngineState>(
  OtbEngineController.new,
  name: 'OtbEngineControllerProvider',
);

class OtbEngineController extends Notifier<OtbEngineState> {
  StreamSubscription<EvalResult>? _evalSub;
  LocalEval? _preMoveEval;
  int _lastCursor = -1;

  @override
  OtbEngineState build() {
    // Capture service reference early so dispose closure doesn't need ref.
    final evaluationService = ref.read(evaluationServiceProvider);

    ref.onDispose(() {
      _evalSub?.cancel();
      _evalSub = null;
      try {
        evaluationService.stop();
      } catch (_) {}
    });

    ref.listen(overTheBoardGameControllerProvider, (prev, next) {
      if (state.isEnabled && next.stepCursor != _lastCursor) {
        _onPositionChanged(prev, next);
        _lastCursor = next.stepCursor;
      }
    });

    // Kick off evaluation of the starting position after the first frame.
    Future.microtask(() {
      if (!ref.mounted) return;
      final gs = ref.read(overTheBoardGameControllerProvider);
      if (state.isEnabled && !gs.finished) {
        _startEvalStream(gs, null, null);
      }
    });

    return const OtbEngineState();
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  void toggleEnabled() {
    final enabled = !state.isEnabled;
    state = state.copyWith(isEnabled: enabled);
    if (!enabled) {
      _cancelEval();
    } else {
      final gs = ref.read(overTheBoardGameControllerProvider);
      _startEvalStream(gs, null, null);
    }
  }

  void togglePanel() {
    state = state.copyWith(isPanelVisible: !state.isPanelVisible);
  }

  // ── Internals ───────────────────────────────────────────────────────────────

  void _cancelEval() {
    _evalSub?.cancel();
    _evalSub = null;
    try {
      ref.read(evaluationServiceProvider).stop();
    } catch (_) {}
  }

  void _onPositionChanged(
    OverTheBoardGameState? prev,
    OverTheBoardGameState next,
  ) {
    // Snapshot pre-move context before resetting.
    final preMoveEval = _preMoveEval;
    final prevTurn = prev?.turn;
    final playedUci = next.stepCursor > 0
        ? next.game.steps[next.stepCursor].sanMove?.move.uci
        : null;
    final bestUci = preMoveEval?.pvs.firstOrNull?.moves.firstOrNull;

    _evalSub?.cancel();
    _evalSub = null;
    _preMoveEval = null;

    state = state.copyWith(
      currentEval: () => null,
      isThinking: !next.finished,
    );

    if (next.finished) return;

    _startEvalStream(next, preMoveEval, prevTurn, playedUci, bestUci);
  }

  void _startEvalStream(
    OverTheBoardGameState gs,
    LocalEval? preMoveEval,
    Side? prevTurn, [
    String? playedUci,
    String? bestUci,
  ]) {
    final variant = gs.game.meta.variant;

    // Steps: skip the initial position (no sanMove) and take up to current cursor.
    final steps = gs.game.steps
        .skip(1)
        .take(gs.stepCursor)
        .map((s) => Step(position: s.position, sanMove: s.sanMove!))
        .toIList();

    final work = EvalWork(
      id: gs.game.id,
      stockfishFlavor: officialStockfishVariants.contains(variant)
          ? StockfishFlavor.latestNoNNUE
          : StockfishFlavor.variant,
      variant: variant,
      threads: maxEngineCores,
      searchTime: const Duration(seconds: 30),
      multiPv: 3,
      threatMode: false,
      initialPosition: gs.game.steps.first.position,
      steps: steps,
    );

    final stream = ref.read(evaluationServiceProvider).evaluate(work);
    if (stream == null) {
      state = state.copyWith(isThinking: false);
      return;
    }

    bool graded = false;

    _evalSub = stream.listen((result) {
      final (_, eval) = result;

      // Grade the move once we have a decent search depth.
      if (!graded && preMoveEval != null && prevTurn != null && eval.depth >= 10) {
        graded = true;
        _gradeMove(preMoveEval, eval, prevTurn, playedUci ?? '', bestUci ?? '');
      }

      _preMoveEval = eval;
      state = state.copyWith(
        currentEval: () => eval,
        isThinking: false,
      );
    });
  }

  void _gradeMove(
    LocalEval preMoveEval,
    LocalEval postMoveEval,
    Side sideBeforeMove,
    String playedUci,
    String bestUci,
  ) {
    // Normalise centipawns to the POV of the side that just moved.
    int cpFromPov(int? cp, int? mate, Side side) {
      if (mate != null) return (mate > 0 ? 32000 : -32000) * (side == Side.white ? 1 : -1);
      if (cp == null) return 0;
      return side == Side.white ? cp : -cp;
    }

    final preCp = cpFromPov(preMoveEval.cp, preMoveEval.mate, sideBeforeMove);
    final postCp = cpFromPov(postMoveEval.cp, postMoveEval.mate, sideBeforeMove);

    // Positive cpGain = player improved the position (great/brilliant).
    // Negative cpGain = player lost centipawns (mistake/blunder).
    final cpGain = postCp - preCp;

    state = state.copyWith(
      lastMoveGrade: () => MoveGradeResult(
        grade: MoveGrade.fromCentipawnGain(cpGain),
        playedUci: playedUci,
        bestUci: bestUci,
      ),
    );
  }
}
