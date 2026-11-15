import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/cloud.dart';
import 'core/store.dart';
import 'ui/screens/athlete_screen.dart';
import 'ui/screens/body_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/program_screen.dart';
import 'ui/screens/progress_screen.dart';
import 'ui/theme.dart';

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
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: widget.store,
      child: CloudScope(
        cloud: widget.cloud,
        child: MaterialApp(
        title: 'Meet Prep Log',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const HomeShell(),
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
    if (!store.loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (store.needsOnboarding) {
      return const AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.light, child: OnboardingScreen());
    }
    const screens = [ProgramScreen(), ProgressScreen(), BodyScreen(), AthleteScreen()];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: IndexedStack(index: tab, children: screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) {
            FocusScope.of(context).unfocus();
            setState(() => tab = i);
          },
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.calendar_view_week_outlined), selectedIcon: Icon(Icons.calendar_view_week), label: 'Program'),
            NavigationDestination(icon: Icon(Icons.show_chart), label: 'Progress'),
            NavigationDestination(
                icon: Icon(Icons.monitor_weight_outlined), selectedIcon: Icon(Icons.monitor_weight), label: 'Body'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Athlete'),
          ],
        ),
      ),
    );
  }
}
