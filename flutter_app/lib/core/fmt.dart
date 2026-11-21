/// Small formatting helpers (no extra packages).
String fmtDur(num seconds) {
  final s = seconds.toInt();
  if (s <= 0) return '0s';
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${sec}s';
  return '${sec}s';
}

DateTime? parseServerTime(String? s) {
  if (s == null || s.isEmpty) return null;
  return DateTime.tryParse(s.replaceFirst(' ', 'T'));
}

String fmtClock(String? s) {
  final d = parseServerTime(s);
  if (d == null) return '';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  return '$h:$mm ${d.hour >= 12 ? 'PM' : 'AM'}';
}

String fmtWhen(String? s) {
  final d = parseServerTime(s);
  if (d == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return fmtClock(s);
  if (diff == 1) return 'Yesterday ${fmtClock(s)}';
  const mon = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day} ${mon[d.month - 1]} ${fmtClock(s)}';
}

String sqlStamp(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:00';

/// "sip:1002@host" or "1002" -> "1002".
String cleanNumber(String s) {
  var v = s.replaceFirst(RegExp(r'^sips?:'), '');
  final at = v.indexOf('@');
  if (at > 0) v = v.substring(0, at);
  return v;
}
