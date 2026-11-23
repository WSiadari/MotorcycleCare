import 'package:flutter/material.dart';

import 'screens/home_router.dart';
import 'screens/auth/welcome_screen.dart';
import 'state/app_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class MotorcycleCareApp extends StatelessWidget {
  const MotorcycleCareApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'MotorcycleCare',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: StartupGate(state: state),
      ),
    );
  }
}

/// Restores a saved login: goes straight to "My motorcycles" or shows Welcome.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key, required this.state});

  final AppState state;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late final Future<bool> _restored = widget.state.restoreSession();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _restored,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.two_wheeler, size: 48, color: AppColors.accent),
                SizedBox(height: 16),
                CircularProgressIndicator(color: AppColors.accent),
              ]),
            ),
          );
        }
        return snap.data == true ? homeFor(widget.state.currentUser!) : const WelcomeScreen();
      },
    );
  }
}
