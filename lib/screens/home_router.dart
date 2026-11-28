import 'package:flutter/material.dart';

import '../models/models.dart';
import 'admin/admin_shell.dart';
import 'mechanic/mechanic_shell.dart';
import 'owner/motorcycles_screen.dart';

/// Home screen of the signed-in user's role.
Widget homeFor(UserAccount user) => switch (user.role) {
      UserRole.owner => const MotorcyclesScreen(),
      UserRole.mechanic => const MechanicShell(),
      UserRole.admin => const AdminShell(),
    };

Route<void> homeRouteFor(UserAccount user) => switch (user.role) {
      UserRole.owner => MotorcyclesScreen.route(),
      _ => MaterialPageRoute(builder: (_) => homeFor(user), settings: const RouteSettings(name: '/home')),
    };
