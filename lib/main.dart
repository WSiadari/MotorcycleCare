import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config.dart';
import 'data/backend.dart';
import 'data/mock_backend.dart';
import 'data/supabase_backend.dart';
import 'services/local_reminder_notifier.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final Backend backend;
  if (AppConfig.useSupabase) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseKey);
    backend = SupabaseBackend();
  } else {
    backend = MockBackend(); // demo data, no setup needed
  }

  runApp(MotorcycleCareApp(state: AppState(backend, notifier: LocalReminderNotifier())));
}
