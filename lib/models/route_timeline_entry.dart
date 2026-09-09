class RouteTimelineEntry {
  const RouteTimelineEntry({
    required this.address,
    required this.timestamp,
    this.isArrived = false,
  });

  final String address;
  final DateTime timestamp;
  final bool isArrived;

  String get formattedTime {
    final hour = timestamp.hour > 12
        ? timestamp.hour - 12
        : (timestamp.hour == 0 ? 12 : timestamp.hour);
    final period = timestamp.hour >= 12 ? 'PM' : 'AM';
    final minute = timestamp.minute.toString().padLeft(2, '0');
    const months = [
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
    return '$hour:$minute $period, ${months[timestamp.month - 1]} ${timestamp.day} ${timestamp.year}';
  }
}
