/// Small formatting helpers (no extra packages needed).
String fmtNum(num value) {
  final n = value.round();
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}$b';
}

String fmtKm(num value) => '${fmtNum(value)} km';

String fmtMonths(int m) => m == 1 ? '1 month' : '$m months';

String fmtRupiah(int value) => 'Rp ${fmtNum(value)}';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime today() => dateOnly(DateTime.now());

DateTime addMonths(DateTime d, int months) {
  final total = d.month - 1 + months;
  final year = d.year + total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, d.day > lastDay ? lastDay : d.day);
}

double monthsBetween(DateTime from, DateTime to) => to.difference(from).inDays / 30.44;

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String fmtTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String fmtMonthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

/// "5 min ago", "2 h ago", "Yesterday", "3 days ago", "2 weeks ago"
String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24 && dateOnly(d) == today()) return '${diff.inHours} h ago';
  final days = today().difference(dateOnly(d)).inDays;
  if (days <= 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  final weeks = days ~/ 7;
  if (weeks < 5) return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
  return fmtDate(d);
}
