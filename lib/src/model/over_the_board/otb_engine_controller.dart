import 'dart:async';
import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  }) => OtbEngineState(
    currentEval:    currentEval    != null ? currentEval()    : this.currentEval,
    lastMoveGrade:  lastMoveGrade  != null ? lastMoveGrade()  : this.lastMoveGrade,
    isEnabled:      isEnabled      ?? this.isEnabled,
    isPanelVisible: isPanelVisible ?? this.isPanelVisible,
    isThinking:     isThinking     ?? this.isThinking,
  );

  /// Arrow shapes derived from top engine PVs.
  ISet<Shape> get shapes {
    final eval = currentEval;
    if (eval == null || !isEnabled) return ISet();
    const brushColors = [0xFF2ECC40, 0xFFFF9F1A, 0xFFE74C3C];
    final arrows = <Shape>[];
    for (var i = 0; i < min(3, eval.pvs.length); i++) {
      final pv = eval.pvs[i];
      if (pv.moves.isEmpty) continue;
      final move = Move.parse(pv.moves[0]);
      if (move == null) continue;
      arrows.add(
        Arrow(
          orig: move.from,
          dest: move.to,
          scale: i == 0 ? 1.0 : 0.85,
          color: Color(brushColors[i]),
        ),
      );
    }
    return ISet(arrows);
  }
}

final otbEngineControllerProvider =
    NotifierProvider.autoDispose<OtbEngineController, OtbEngineState>(
  OtbEngineController.new,
  name: 'OtbEngineControllerProvider',
);

class OtbEngineController extends AutoDisposeNotifier<OtbEngineState> {
  StreamSubscription<EvalResult>? _evalSub;
  LocalEval? _preMoveEval;
  int _lastCursor = -1;

  @override
  OtbEngineState build() {
    ref.onDispose(_dispose);

    ref.listen(overTheBoardGameControllerProvider, (prev, next) {
      if (state.isEnabled && next.stepCursor != _lastCursor) {
        _onPositionChanged(prev, next);
        _lastCursor = next.stepCursor;
      }
    });

    // Evaluate the starting position
    final gameState = ref.read(overTheBoardGameControllerProvider);
    if (!gameState.finished) {
      Future.microtask(() => _startEvalStream(gameState, null, null));
    }

    return const OtbEngineState();
  }

  void toggleEnabled() {
    final enabled = !state.isEnabled;
    state = state.copyWith(isEnabled: enabled);
    if (!enabled) {
      _dispose();
    } else {
      final gs = ref.read(overTheBoardGameControllerProvider);
      _startEvalStream(gs, null, null);
    }
  }

  void togglePanel() =>
      state = state.copyWith(isPanelVisible: !state.isPanelVisible);

  // ── internals ────────────────────────────────────────────────────────────

  void _dispose() {
    _evalSub?.cancel();
    _evalSub = null;
    try { ref.read(evaluationServiceProvider).stop(); } catch (_) {}
  }

  void _onPositionChanged(
    OverTheBoardGameState? prev,
    OverTheBoardGameState next,
  ) {
    final preMoveEval = _preMoveEval;
    final prevTurn = prev?.turn;
    final playedUci = next.stepCursor > 0
        ? next.game.steps[next.stepCursor].sanMove?.move.uci
        : null;
    final bestUci = preMoveEval?.pvs.firstOrNull?.moves.firstOrNull;

    // Cancel previous stream before starting new one
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

    // Build steps list (skip the initial position which has no sanMove)
    final steps = gs.game.steps
        .skip(1)
        .take(gs.stepCursor)
        .map((s) => Step(position: s.position, sanMove: s.sanMove!))
        .toIList();

    final work = EvalWork(
      id: gs.game.id,
      stockfishFlavor: officialStockfishVariants.contains(variant)
          ? StockfishFlavor.standard
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

      // Grade the move once we have a reasonable depth
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
    // cp is from white's POV; normalise to the player's POV
    int cpFromPov(int? cp, int? mate, Side side) {
      if (mate != null) return (mate > 0 ? 32000 : -32000) * (side == Side.white ? 1 : -1);
      if (cp == null) return 0;
      return side == Side.white ? cp : -cp;
    }

    final preCp  = cpFromPov(preMoveEval.cp,  preMoveEval.mate,  sideBeforeMove);
    final postCp = cpFromPov(postMoveEval.cp, postMoveEval.mate, sideBeforeMove);

    // After the move it's the opponent's turn: opponent's advantage = player's loss.
    // cpGain = how much the position improved FOR the player who just moved.
    final cpGain = postCp - preCp; // negative = player made a mistake

    state = state.copyWith(
      lastMoveGrade: () => MoveGradeResult(
        grade: MoveGrade.fromCentipawnGain(cpGain),
        playedUci: playedUci,
        bestUci: bestUci,
      ),
    );
  }
}
