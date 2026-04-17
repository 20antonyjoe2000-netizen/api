class Scheme {
  final int schemeCode;
  final String schemeName;
  final String? category;   // from AMFI NAVAll.txt
  final String? fundHouse;  // from AMFI NAVAll.txt

  const Scheme({
    required this.schemeCode,
    required this.schemeName,
    this.category,
    this.fundHouse,
  });

  factory Scheme.fromJson(Map<String, dynamic> json) {
    return Scheme(
      schemeCode: json['schemeCode'] as int,
      schemeName: json['schemeName'] as String,
    );
  }
}
