import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/cloud.dart';
import 'core/calc.dart';
import 'core/store.dart';
import 'l10n/l10n.dart';
import 'ui/screens/athlete_screen.dart';
import 'ui/screens/body_screen.dart';
import 'ui/screens/coach_screen.dart';
import 'ui/screens/meet_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/program_screen.dart';
import 'ui/screens/progress_screen.dart';
import 'ui/theme.dart';
import 'ui/motion.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  final cloud = CloudSync(store);
  runApp(MeetPrepApp(store: store, cloud: cloud));
  store.load();
  cloud.init();
}

class MeetPrepApp extends StatefulWidget {
  final AppStore store;
  final CloudSync cloud;
  const MeetPrepApp({super.key, required this.store, required this.cloud});

  @override
  State<MeetPrepApp> createState() => _MeetPrepAppState();
}

class _MeetPrepAppState extends State<MeetPrepApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Save straight away when the app goes to the background.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      widget.store.flush();
      widget.cloud.flush();
    } else if (state == AppLifecycleState.resumed) {
      // New comments or programs from a coach may be waiting.
      widget.cloud.refreshCoach();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: widget.store,
      child: CloudScope(
        cloud: widget.cloud,
        child: ValueListenableBuilder<String>(
          valueListenable: widget.store.localeCode,
          builder: (context, code, _) => MaterialApp(
            title: 'Meet Prep Log',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            locale: code == 'system' ? null : Locale(code),
            supportedLocales: kSupportedLocales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              // Month and weekday names follow the app language.
              dateLang = isArabic(context) ? 'ar' : 'en';
              return child ?? const SizedBox.shrink();
            },
            home: const HomeShell(),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    // Cross-fade between loading, onboarding and the app.
    final stage = !store.loaded ? 0 : (store.needsOnboarding ? 1 : 2);
    return AnimatedSwitcher(
      duration: reduceMotion(context) ? Duration.zero : kMotionSlow,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(key: ValueKey(stage), child: _content(context, store)),
    );
  }

  Widget _content(BuildContext context, AppStore store) {
    if (!store.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (store.needsOnboarding) {
      return const AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.light, child: OnboardingScreen());
    }
    final cloud = CloudScope.of(context);
    final coach = cloud.isCoach;
    final screens = [
      // Keys keep each tab's state when the Coach tab appears or disappears.
      const ProgramScreen(key: ValueKey('program')),
      const ProgressScreen(key: ValueKey('progress')),
      const MeetScreen(key: ValueKey('meet')),
      const BodyScreen(key: ValueKey('body')),
      if (coach) const CoachScreen(key: ValueKey('coach')),
      const AthleteScreen(key: ValueKey('athlete')),
    ];
    final index = tab.clamp(0, screens.length - 1).toInt();
    final athleteBadge = cloud.inbox.length;
    final programBadge = cloud.unreadFromCoach;
    final coachBadge = cloud.myId == null ? 0 : cloud.unread.where((c) => c.athleteId != cloud.myId).length;
    Widget badge(Widget icon, int n) => n > 0 ? Badge(label: Text('$n'), child: icon) : icon;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: FadeIndexedStack(index: index, children: screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) {
            FocusScope.of(context).unfocus();
            setState(() => tab = i);
          },
          destinations: [
            NavigationDestination(
                icon: badge(const Icon(Icons.calendar_view_week_outlined), programBadge),
                selectedIcon: badge(const Icon(Icons.calendar_view_week), programBadge),
                label: tr(context, 'Program')),
            NavigationDestination(icon: const Icon(Icons.show_chart), label: tr(context, 'Progress')),
            NavigationDestination(
                icon: const Icon(Icons.emoji_events_outlined),
                selectedIcon: const Icon(Icons.emoji_events),
                label: tr(context, 'Meet')),
            NavigationDestination(
                icon: const Icon(Icons.monitor_weight_outlined),
                selectedIcon: const Icon(Icons.monitor_weight),
                label: tr(context, 'Body')),
            if (coach)
              NavigationDestination(
                  icon: badge(const Icon(Icons.groups_outlined), coachBadge),
                  selectedIcon: badge(const Icon(Icons.groups), coachBadge),
                  label: tr(context, 'Coach')),
            NavigationDestination(
                icon: badge(const Icon(Icons.person_outline), athleteBadge),
                selectedIcon: badge(const Icon(Icons.person), athleteBadge),
                label: tr(context, 'Athlete')),
          ],
        ),
      ),
    );
  }
}
