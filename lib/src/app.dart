import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n_esperanto/l10n_esperanto.dart';
import 'package:lichess_mobile/l10n/l10n.dart';
import 'package:lichess_mobile/src/binding.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_preferences.dart';
import 'package:lichess_mobile/src/model/common/preloaded_data.dart';
import 'package:lichess_mobile/src/model/log/app_log_service.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/model/settings/general_preferences.dart';
import 'package:lichess_mobile/src/tab_scaffold.dart';
import 'package:lichess_mobile/src/theme.dart';
import 'package:lichess_mobile/src/utils/screen.dart';

/// Application initialization and main entry point.
class AppInitializationScreen extends ConsumerWidget {
  const AppInitializationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<PreloadedData>>(preloadedDataProvider, (_, state) {
      if (state.hasValue || state.hasError) {
        FlutterNativeSplash.remove();
      }
    });

    switch (ref.watch(preloadedDataProvider)) {
      case AsyncData():
        return const Application();
      case AsyncError(:final error, :final stackTrace):
        debugPrint('SEVERE: [App] could not initialize app; $error\n$stackTrace');
        return const SizedBox.shrink();
      case _:
        return const SizedBox.shrink();
    }
  }
}

/// The main application widget.
class Application extends ConsumerStatefulWidget {
  const Application({super.key});

  @override
  ConsumerState<Application> createState() => _AppState();
}

class _AppState extends ConsumerState<Application> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  Future<void> _screenSizeBasedInitialization(WidgetRef ref) async {
    const kDoneScreenSizeInitKey = 'done_screen_size_init_v1';

    final prefs = LichessBinding.instance.sharedPreferences;
    if (prefs.getBool(kDoneScreenSizeInitKey) == true) {
      return;
    }

    final mediaQueryData = MediaQueryData.fromView(
      WidgetsBinding.instance.platformDispatcher.views.first,
    );
    final isTablet = mediaQueryData.size.shortestSide > FormFactor.tablet;
    final isSmallScreen = estimateHeightMinusBoard(mediaQueryData) < kSmallHeightMinusBoard;
    final showEngineLines =
        isTablet || estimateHeightMinusBoard(mediaQueryData) > kSmallHeightMinusBoard - 30;

    final smallBoard = isTablet || isSmallScreen;

    await ref
        .read(analysisPreferencesProvider.notifier)
        .save(
          ref
              .read(analysisPreferencesProvider)
              .copyWith(smallBoard: smallBoard, showEngineLines: showEngineLines),
        );

    await prefs.setBool(kDoneScreenSizeInitKey, true);
  }

  @override
  void initState() {
    _screenSizeBasedInitialization(ref);

    ref.read(appLogServiceProvider).start();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final generalPrefs = ref.watch(generalPreferencesProvider);
    final boardPrefs = ref.watch(boardPreferencesProvider);
    final theme = makeAppTheme(context, generalPrefs, boardPrefs);

    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    return MaterialApp(
      navigatorKey: _navigatorKey,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        MaterialLocalizationsEo.delegate,
        CupertinoLocalizationsEo.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      title: 'A1Chess',
      locale: generalPrefs.locale,
      theme: theme.copyWith(
        navigationBarTheme: isIOS
            ? null
            : NavigationBarTheme.of(
                context,
              ).copyWith(height: isShortVerticalScreen(context) ? 60 : null),
      ),
      home: const MainTabScaffold(),
      navigatorObservers: [rootNavPageRouteObserver],
    );
  }
}
