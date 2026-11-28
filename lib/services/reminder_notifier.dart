import '../models/models.dart';

/// Shows a maintenance reminder to the owner.
/// [AppState] only calls it for new reminders of the signed-in owner's own motorcycles,
/// and only when MotorcycleOwner.notificationEnabled is on.
abstract class ReminderNotifier {
  Future<void> show(Reminder reminder, {required String title});
}

/// Used in tests and on platforms without notifications.
class SilentReminderNotifier implements ReminderNotifier {
  const SilentReminderNotifier();

  @override
  Future<void> show(Reminder reminder, {required String title}) async {}
}
