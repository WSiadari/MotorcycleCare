import 'package:flutter/material.dart';

import '../models/models.dart';
import 'admin/admin_shell.dart';
import 'mechanic/mechanic_shell.dart';
import 'owner/motorcycles_screen.dart';

/// Use case diagram: one app, three actors. After "Log In → Login successful?"
/// each role opens its own dashboard from its activity diagram.
Widget homeFor(UserAccount user) => switch (user.role) {
      UserRole.owner => const MotorcyclesScreen(), // user activity: Manage Motorcycles
      UserRole.mechanic => const MechanicShell(), // mechanic activity: Mechanic Dashboard
      UserRole.admin => const AdminShell(), // admin activity: Admin Dashboard
    };

Route<void> homeRouteFor(UserAccount user) => switch (user.role) {
      UserRole.owner => MotorcyclesScreen.route(),
      _ => MaterialPageRoute(builder: (_) => homeFor(user), settings: const RouteSettings(name: '/home')),
    };
