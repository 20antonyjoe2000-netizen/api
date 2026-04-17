class NavEntry {
  final DateTime date;
  final double nav;

  const NavEntry({required this.date, required this.nav});

  factory NavEntry.fromJson(Map<String, dynamic> json) {
    final parts = (json['date'] as String).split('-');
    // API format: DD-MM-YYYY
    final date = DateTime(
      int.parse(parts[2]),
      int.parse(parts[1]),
      int.parse(parts[0]),
    );
    return NavEntry(
      date: date,
      nav: double.parse(json['nav'] as String),
    );
  }
}
