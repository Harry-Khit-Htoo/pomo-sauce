import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../../timer/pomodoro_state.dart';
import '../focus/focus_screen.dart';
import '../habits/habits_screen.dart';
import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';

/// Bottom-nav shell.
///
/// This is also the single owner of *presenting* the Focus Display. Starting a
/// session anywhere in the app opens it automatically, and so does coming back
/// to an app that still has a session running - the user should never have to
/// hunt for their own timer. It is always a push, never a replace, so back
/// still returns to the shell without stopping the timer.
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell>
    with WidgetsBindingObserver {
  int _index = 0;

  /// Guards against stacking two Focus Displays when several triggers fire at
  /// once (start + resume, say).
  bool _focusRouteOpen = false;

  static const _tabs = [
    HomeScreen(),
    HabitsScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cold start straight into a session that is still running.
    WidgetsBinding.instance.addPostFrameCallback((_) => _presentIfActive());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Re-sync from the wall clock first, then show the timer if one survived
    // in the background service while we were away.
    ref.read(pomodoroProvider.notifier).resync().then((_) {
      if (mounted) _presentIfActive();
    });
  }

  void _presentIfActive() {
    final status = ref.read(pomodoroProvider).status;
    if (status == TimerStatus.idle) return;
    _openFocus();
  }

  Future<void> _openFocus() async {
    if (_focusRouteOpen || !mounted) return;
    final navigator = Navigator.of(context);
    // Something else is already on top (a settings page, a sheet); do not
    // yank the user out of it.
    if (navigator.canPop()) return;

    _focusRouteOpen = true;
    await navigator.push(
      MaterialPageRoute(builder: (_) => const FocusScreen()),
    );
    if (mounted) _focusRouteOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    // Any transition out of idle - a session starting, or an interval ending
    // and ringing - brings the Focus Display up on its own.
    ref.listen(pomodoroProvider, (previous, next) {
      final was = previous?.status ?? TimerStatus.idle;
      if (was == TimerStatus.idle && next.status != TimerStatus.idle) {
        _openFocus();
      }
    });

    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Timer',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline),
            selectedIcon: Icon(Icons.check_circle),
            label: 'Habits',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
