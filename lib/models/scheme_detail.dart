import 'nav_entry.dart';

class SchemeMeta {
  final String fundHouse;
  final String schemeType;
  final String schemeCategory;
  final int schemeCode;
  final String schemeName;
  final String? isinGrowth;
  final String? isinDivReinvestment;

  const SchemeMeta({
    required this.fundHouse,
    required this.schemeType,
    required this.schemeCategory,
    required this.schemeCode,
    required this.schemeName,
    this.isinGrowth,
    this.isinDivReinvestment,
  });

  factory SchemeMeta.fromJson(Map<String, dynamic> json) {
    return SchemeMeta(
      fundHouse: json['fund_house'] as String,
      schemeType: json['scheme_type'] as String,
      schemeCategory: json['scheme_category'] as String,
      schemeCode: json['scheme_code'] as int,
      schemeName: json['scheme_name'] as String,
      isinGrowth: json['isin_growth'] as String?,
      isinDivReinvestment: json['isin_div_reinvestment'] as String?,
    );
  }
}

class SchemeDetail {
  final SchemeMeta meta;
  final List<NavEntry> navHistory; // chronological order (oldest first)

  const SchemeDetail({required this.meta, required this.navHistory});

  factory SchemeDetail.fromJson(Map<String, dynamic> json) {
    final meta = SchemeMeta.fromJson(json['meta'] as Map<String, dynamic>);
    final rawData = (json['data'] as List<dynamic>)
        .map((e) => NavEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    // API returns newest-first; reverse so chart plots oldest→newest
    return SchemeDetail(
      meta: meta,
      navHistory: rawData.reversed.toList(),
    );
  }

  NavEntry? get latestNav => navHistory.isNotEmpty ? navHistory.last : null;
}
