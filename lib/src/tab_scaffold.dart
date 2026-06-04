import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:lichess_mobile/l10n/l10n.dart';
import 'package:lichess_mobile/src/styles/lichess_icons.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/view/home/rdchess_home_screen.dart';
import 'package:lichess_mobile/src/view/over_the_board/over_the_board_screen.dart';
import 'package:lichess_mobile/src/view/settings/settings_screen.dart';
import 'package:lichess_mobile/src/widgets/background.dart';
import 'package:material_symbols_icons/symbols.dart';

enum BottomTab {
  play,
  settings;

  String label(AppLocalizations strings) {
    switch (this) {
      case BottomTab.play:
        return strings.play;
      case BottomTab.settings:
        return strings.settingsSettings;
    }
  }

  IconData get icon {
    switch (this) {
      case BottomTab.play:
        return LichessIcons.chess;
      case BottomTab.settings:
        return Symbols.settings;
    }
  }
}

final currentBottomTabProvider = StateProvider<BottomTab>((ref) => BottomTab.play);

final currentNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  final currentTab = ref.watch(currentBottomTabProvider);
  switch (currentTab) {
    case BottomTab.play:
      return playNavigatorKey;
    case BottomTab.settings:
      return settingsNavigatorKey;
  }
});

final currentRootScrollControllerProvider = Provider<ScrollController>((ref) {
  final currentTab = ref.watch(currentBottomTabProvider);
  switch (currentTab) {
    case BottomTab.play:
      return playScrollController;
    case BottomTab.settings:
      return settingsScrollController;
  }
});

final playNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'play');
final settingsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'settings');

final playScrollController = ScrollController(debugLabel: 'PlayScroll');
final settingsScrollController = ScrollController(debugLabel: 'SettingsScroll');

final RouteObserver<PageRoute<void>> rootNavPageRouteObserver = RouteObserver<PageRoute<void>>();

final playTabInteraction = _BottomTabInteraction();
final settingsTabInteraction = _BottomTabInteraction();

class _BottomTabInteraction extends ChangeNotifier {
  void notifyItemTapped() {
    notifyListeners();
  }
}

/// Main scaffold that provides the bottom navigation bar and tab switching view.
class MainTabScaffold extends ConsumerWidget {
  const MainTabScaffold({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentBottomTabProvider);

    final extendBody = Theme.of(context).platform == TargetPlatform.iOS;

    return FullScreenBackground(
      child: MainTabScaffoldProperties(
        extendBody: extendBody,
        child: Scaffold(
          body: _TabSwitchingView(currentTab: currentTab, tabBuilder: _tabBuilder),
          extendBody: extendBody,
          bottomNavigationBar: Theme.of(context).platform == TargetPlatform.iOS
              ? _CupertinoTabBar(
                  height: 50,
                  backgroundColor: NavigationBarTheme.of(context).backgroundColor,
                  border: const Border(top: BorderSide(color: Colors.transparent)),
                  activeColor: ColorScheme.of(context).onSurface,
                  currentIndex: currentTab.index,
                  items: [
                    for (final tab in BottomTab.values)
                      BottomNavigationBarItem(
                        icon: Icon(tab.icon, fill: tab == currentTab ? 1 : 0),
                        label: tab.label(context.l10n),
                      ),
                  ],
                  onTap: (i) => _onItemTapped(ref, i),
                )
              : NavigationBar(
                  selectedIndex: currentTab.index,
                  destinations: [
                    for (final tab in BottomTab.values)
                      NavigationDestination(
                        icon: Icon(tab.icon, fill: tab == currentTab ? 1 : 0),
                        label: tab.label(context.l10n),
                      ),
                  ],
                  onDestinationSelected: (i) => _onItemTapped(ref, i),
                ),
        ),
      ),
    );
  }

  void _onItemTapped(WidgetRef ref, int index) {
    final curTab = ref.read(currentBottomTabProvider);
    final tappedTab = BottomTab.values[index];

    if (tappedTab == curTab) {
      final navState = ref.read(currentNavigatorKeyProvider).currentState;
      final scrollController = ref.read(currentRootScrollControllerProvider);
      if (navState?.canPop() == true) {
        navState?.popUntil((route) => route.isFirst);
      } else if (scrollController.hasClients && scrollController.offset > 0) {
        scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        switch (tappedTab) {
          case BottomTab.play:
            playTabInteraction.notifyItemTapped();
          case BottomTab.settings:
            settingsTabInteraction.notifyItemTapped();
        }
      }
    } else {
      ref.read(currentBottomTabProvider.notifier).state = tappedTab;
    }
  }

  Widget _tabBuilder(BuildContext context, int index) {
    switch (index) {
      case 0:
        return _MaterialTabView(
          navigatorKey: playNavigatorKey,
          tab: BottomTab.play,
          builder: (context) => const RdChessHomeScreen(),
        );
      case 1:
        return _MaterialTabView(
          navigatorKey: settingsNavigatorKey,
          tab: BottomTab.settings,
          builder: (context) => const SettingsScreen(),
        );
      default:
        assert(false, 'Unexpected tab');
        return const SizedBox.shrink();
    }
  }
}

/// [InheritedWidget] providing [Scaffold] properties of the [MainTabScaffold].
class MainTabScaffoldProperties extends InheritedWidget {
  /// Constructs a new [MainTabScaffoldProperties].
  const MainTabScaffoldProperties({required super.child, required this.extendBody, super.key});

  /// The value of [Scaffold.extendBody] defined in the [MainTabScaffold].
  final bool extendBody;

  @override
  bool updateShouldNotify(MainTabScaffoldProperties oldWidget) {
    return extendBody != oldWidget.extendBody;
  }

  /// Retrieve the [MainTabScaffoldProperties] background color from the context.
  static MainTabScaffoldProperties? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainTabScaffoldProperties>();
  }

  /// Returns true if the [MainTabScaffold] has an extended body.
  static bool hasExtendedBody(BuildContext context) {
    final properties = maybeOf(context);
    return properties != null && properties.extendBody;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('extendBody', extendBody));
  }
}

// --

class _TabSwitchingView extends StatefulWidget {
  const _TabSwitchingView({required this.currentTab, required this.tabBuilder});

  final BottomTab currentTab;
  final IndexedWidgetBuilder tabBuilder;

  @override
  _TabSwitchingViewState createState() => _TabSwitchingViewState();
}

class _TabSwitchingViewState extends State<_TabSwitchingView> {
  final List<bool> shouldBuildTab = <bool>[];
  final List<FocusScopeNode> tabFocusNodes = <FocusScopeNode>[];

  final List<FocusScopeNode> discardedNodes = <FocusScopeNode>[];

  @override
  void initState() {
    super.initState();
    shouldBuildTab.addAll(List<bool>.filled(BottomTab.values.length, false));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _focusActiveTab();
  }

  @override
  void didUpdateWidget(_TabSwitchingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _focusActiveTab();
  }

  void _focusActiveTab() {
    if (tabFocusNodes.length != BottomTab.values.length) {
      if (tabFocusNodes.length > BottomTab.values.length) {
        discardedNodes.addAll(tabFocusNodes.sublist(BottomTab.values.length));
        tabFocusNodes.removeRange(BottomTab.values.length, tabFocusNodes.length);
      } else {
        tabFocusNodes.addAll(
          List<FocusScopeNode>.generate(
            BottomTab.values.length - tabFocusNodes.length,
            (int index) =>
                FocusScopeNode(debugLabel: '$MainTabScaffold Tab ${index + tabFocusNodes.length}'),
          ),
        );
      }
    }
    FocusScope.of(context).setFirstFocus(tabFocusNodes[widget.currentTab.index]);
  }

  @override
  void dispose() {
    for (final FocusScopeNode focusScopeNode in tabFocusNodes) {
      focusScopeNode.dispose();
    }
    for (final FocusScopeNode focusScopeNode in discardedNodes) {
      focusScopeNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List<Widget>.generate(BottomTab.values.length, (int index) {
        final bool active = index == widget.currentTab.index;
        shouldBuildTab[index] = active || shouldBuildTab[index];

        return HeroMode(
          enabled: active,
          child: Offstage(
            offstage: !active,
            child: TickerMode(
              enabled: active,
              child: FocusScope(
                node: tabFocusNodes[index],
                child: Builder(
                  builder: (BuildContext context) {
                    return shouldBuildTab[index] ? widget.tabBuilder(context, index) : Container();
                  },
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _MaterialTabView extends ConsumerStatefulWidget {
  const _MaterialTabView({
    // ignore: unused_element_parameter
    super.key,
    required this.tab,
    this.builder,
    this.navigatorKey,
    // ignore: unused_element_parameter
    this.routes,
    // ignore: unused_element_parameter
    this.onGenerateRoute,
    // ignore: unused_element_parameter
    this.onUnknownRoute,
    // ignore: unused_element_parameter
    this.navigatorObservers = const <NavigatorObserver>[],
    // ignore: unused_element_parameter
    this.restorationScopeId,
  });

  final BottomTab tab;

  final WidgetBuilder? builder;

  final GlobalKey<NavigatorState>? navigatorKey;

  final Map<String, WidgetBuilder>? routes;

  final RouteFactory? onGenerateRoute;

  final RouteFactory? onUnknownRoute;

  final List<NavigatorObserver> navigatorObservers;

  final String? restorationScopeId;

  @override
  ConsumerState<_MaterialTabView> createState() => _MaterialTabViewState();
}

class _MaterialTabViewState extends ConsumerState<_MaterialTabView> {
  // ignore: avoid-late-keyword
  late HeroController _heroController;

  // ignore: avoid-late-keyword
  late List<NavigatorObserver> _navigatorObservers;

  @override
  void initState() {
    super.initState();
    _heroController = MaterialApp.createMaterialHeroController();
    _updateObservers();
  }

  @override
  void didUpdateWidget(_MaterialTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigatorKey != oldWidget.navigatorKey ||
        widget.navigatorObservers != oldWidget.navigatorObservers) {
      _updateObservers();
    }
  }

  void _updateObservers() {
    _navigatorObservers = List<NavigatorObserver>.of(widget.navigatorObservers)
      ..add(_heroController);
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(currentBottomTabProvider);
    final enablePopHandler = currentTab == widget.tab;
    return NavigatorPopHandler(
      onPopWithResult: enablePopHandler
          ? (_) {
              widget.navigatorKey?.currentState?.maybePop();
            }
          : null,
      enabled: enablePopHandler,
      child: Navigator(
        key: widget.navigatorKey,
        onGenerateRoute: _onGenerateRoute,
        onUnknownRoute: _onUnknownRoute,
        observers: _navigatorObservers,
        restorationScopeId: widget.restorationScopeId,
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final String? name = settings.name;
    WidgetBuilder? routeBuilder;
    if (name == Navigator.defaultRouteName && widget.builder != null) {
      routeBuilder = widget.builder;
    } else if (widget.routes != null) {
      routeBuilder = widget.routes![name];
    }
    if (routeBuilder != null) {
      return MaterialPageRoute<dynamic>(builder: routeBuilder, settings: settings);
    }
    if (widget.onGenerateRoute != null) {
      return widget.onGenerateRoute!(settings);
    }
    return null;
  }

  Route<dynamic>? _onUnknownRoute(RouteSettings settings) {
    assert(() {
      if (widget.onUnknownRoute == null) {
        throw FlutterError(
          'Could not find a generator for route $settings in the $runtimeType.\n'
          'Generators for routes are searched for in the following order:\n'
          ' 1. For the "/" route, the "builder" property, if non-null, is used.\n'
          ' 2. Otherwise, the "routes" table is used, if it has an entry for '
          'the route.\n'
          ' 3. Otherwise, onGenerateRoute is called. It should return a '
          'non-null value for any valid route not handled by "builder" and "routes".\n'
          ' 4. Finally if all else fails onUnknownRoute is called.\n'
          'Unfortunately, onUnknownRoute was not set.',
        );
      }
      return true;
    }());
    final Route<dynamic>? result = widget.onUnknownRoute!(settings);
    assert(() {
      if (result == null) {
        throw FlutterError(
          'The onUnknownRoute callback returned null.\n'
          'When the $runtimeType requested the route $settings from its '
          'onUnknownRoute callback, the callback returned null. Such callbacks '
          'must never return null.',
        );
      }
      return true;
    }());
    return result;
  }
}

// Code taken and adapted from
// https://github.com/flutter/flutter/blob/main/packages/flutter/lib/src/cupertino/bottom_tab_bar.dart#L60

const double _kTabBarHeight = 50.0;

const Color _kDefaultTabBarBorderColor = CupertinoDynamicColor.withBrightness(
  color: Color(0x4D000000),
  darkColor: Color(0x29000000),
);
const Color _kDefaultTabBarInactiveColor = CupertinoColors.inactiveGray;

class _CupertinoTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _CupertinoTabBar({
    // ignore: unused_element_parameter
    super.key,
    required this.items,
    this.onTap,
    this.currentIndex = 0,
    this.backgroundColor,
    this.activeColor,
    // ignore: unused_element_parameter
    this.inactiveColor = _kDefaultTabBarInactiveColor,
    // ignore: unused_element_parameter
    this.iconSize = 30.0,
    this.height = _kTabBarHeight,
    this.border = const Border(
      top: BorderSide(
        color: _kDefaultTabBarBorderColor,
        width: 0.0,
      ),
    ),
  }) : assert(items.length >= 2, "Tabs need at least 2 items to conform to Apple's HIG"),
       assert(0 <= currentIndex && currentIndex < items.length),
       assert(height >= 0.0);

  final List<BottomNavigationBarItem> items;
  final ValueChanged<int>? onTap;
  final int currentIndex;
  final Color? backgroundColor;
  final Color? activeColor;
  final Color inactiveColor;
  final double iconSize;
  final double height;
  final Border border;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(border: border),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: SizedBox(
          height: height + bottomPadding,
          child: IconTheme(
            data: IconThemeData(color: activeColor, size: iconSize),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < items.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap?.call(i),
                      child: Padding(
                        padding: EdgeInsets.only(bottom: bottomPadding),
                        child: SizedBox(
                          height: height,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              items[i].icon,
                              if (items[i].label != null)
                                Text(
                                  items[i].label!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: i == currentIndex ? activeColor : inactiveColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
