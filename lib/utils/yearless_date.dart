/// Year 4 is a leap year, so February 29 fits in a [DateTime].
///
/// [Event.originalDate] cannot be null, and Group stays Hive field 6, so a
/// missing year is stored as this year. It is a sentinel, not a real year.
/// Never show it in the interface, in reminders, or in a backup file.
const int kYearlessSentinelYear = 4;

bool isYearlessDate(DateTime date) => date.year == kYearlessSentinelYear;

DateTime yearlessDate(int month, int day) => DateTime(kYearlessSentinelYear, month, day);

const List<String> _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Month and day only. Uses a leap year internally so February 29 formats.
String formatMonthDay(DateTime date) {
  return '${_monthNames[date.month - 1]} ${date.day}';
}

/// Full date for a known year. Yearless dates omit the year entirely.
String formatFullDate(DateTime date) {
  if (isYearlessDate(date)) return formatMonthDay(date);
  return '${formatMonthDay(date)}, ${date.year}';
}

/// Backup form. Known years stay `YYYY-MM-DD`. Yearless dates are `MM/DD`.
String formatStoredDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  if (isYearlessDate(date)) return '$month/$day';
  final year = date.year.toString().padLeft(4, '0');
  return '$year-$month-$day';
}
