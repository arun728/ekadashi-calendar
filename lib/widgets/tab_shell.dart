import 'package:flutter/material.dart';

/// Each tab keeps its own navigation stack, as iOS does with a
/// NavigationStack per tab: pages pushed from a tab (Ekadashi details,
/// widget preview) stay in that tab, above it the tab bar stays visible,
/// and sheets and the paywall cover everything from the root navigator.
class TabNavigator extends StatelessWidget {
  const TabNavigator({
    super.key,
    required this.index,
    required this.navigatorKey,
    required this.observer,
  });

  final int index;
  final GlobalKey<NavigatorState> navigatorKey;
  final NavigatorObserver observer;

  @override
  Widget build(BuildContext context) => HeroControllerScope(
    controller: MaterialApp.createMaterialHeroController(),
    child: Navigator(
      key: navigatorKey,
      observers: [observer],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        // The tab's root page reads its content from the shell, so it
        // rebuilds whenever the shell does.
        builder: (_) => Builder(
          builder: (context) => TabContentScope.of(context).build(index),
        ),
      ),
    ),
  );
}

/// The shell's tab contents, above every tab navigator.
class TabContentScope extends InheritedWidget {
  const TabContentScope({super.key, required this.build, required super.child});

  final Widget Function(int index) build;

  static TabContentScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabContentScope>()!;

  @override
  bool updateShouldNotify(TabContentScope oldWidget) => true;
}

/// Calls [onChange] after any push or pop in a tab's navigator.
class TabNavigatorObserver extends NavigatorObserver {
  TabNavigatorObserver(this.onChange);

  final VoidCallback onChange;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChange();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChange();
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChange();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      onChange();
}

/// The items a tab puts in the shared top bar, like a SwiftUI toolbar:
/// [leading] beside the back-to-search button and [actions] before the
/// search button (Calendar's Today, Add and Google; Panchang's Today and
/// calculation notes). The tab calls [refresh] when they change.
class TabBarSlots extends ChangeNotifier {
  WidgetBuilder? _leading;
  List<Widget> Function(BuildContext context)? _actions;
  bool _scheduled = false;

  Widget? leading(BuildContext context) => _leading?.call(context);
  List<Widget> actions(BuildContext context) =>
      _actions?.call(context) ?? const [];
  bool get hasLeading => _leading != null;

  /// Sets the builders; safe to call from initState.
  void attach({
    WidgetBuilder? leading,
    List<Widget> Function(BuildContext context)? actions,
  }) {
    _leading = leading;
    _actions = actions;
    refresh();
  }

  void detach() {
    _leading = null;
    _actions = null;
    refresh();
  }

  /// Rebuilds the top bar after the current frame.
  void refresh() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}
