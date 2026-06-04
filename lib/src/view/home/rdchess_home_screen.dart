import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/network/connectivity.dart';
import 'package:lichess_mobile/src/styles/lichess_icons.dart';
import 'package:lichess_mobile/src/view/offline_computer/offline_computer_game_screen.dart';
import 'package:lichess_mobile/src/view/over_the_board/over_the_board_screen.dart';
import 'package:lichess_mobile/src/view/play/play_bottom_sheet.dart';
import 'package:lichess_mobile/src/view/settings/settings_screen.dart';
import 'package:material_symbols_icons/symbols.dart';

class RdChessHomeScreen extends ConsumerWidget {
  const RdChessHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(onlineStatusProvider).value ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo-transp.png',
                      height: 72,
                      errorBuilder: (_, __, ___) => Icon(
                        LichessIcons.chess,
                        size: 72,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'A1 Chess',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pick how you want to play',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ── Play cards ──────────────────────────────────────────────
              _PlayCard(
                icon: Icons.memory_rounded,
                title: 'Play vs Computer',
                subtitle: 'Challenge Stockfish',
                accentColor: theme.colorScheme.primary,
                onTap: () => Navigator.of(context).push(
                  OfflineComputerGameScreen.buildRoute(),
                ),
              ),

              const SizedBox(height: 14),

              _PlayCard(
                icon: Symbols.chess_pawn_rounded,
                title: 'Over the Board',
                subtitle: 'Two players, one device',
                accentColor: theme.colorScheme.secondary,
                onTap: () => Navigator.of(context).push(
                  OverTheBoardScreen.buildRoute(),
                ),
              ),

              const SizedBox(height: 14),

              _PlayCard(
                icon: Icons.wifi_rounded,
                title: 'Online Play',
                subtitle: isOnline ? 'Play on lichess.org' : 'No internet connection',
                accentColor: isOnline
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.outline,
                enabled: isOnline,
                onTap: isOnline
                    ? () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useRootNavigator: true,
                          builder: (_) => const PlayBottomSheet(),
                        )
                    : null,
              ),

              const SizedBox(height: 32),

              // ── Settings shortcut ────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  SettingsScreen.buildRoute(),
                ),
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Settings'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayCard extends StatelessWidget {
  const _PlayCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 26, color: accentColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: enabled
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: enabled
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
                    : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
