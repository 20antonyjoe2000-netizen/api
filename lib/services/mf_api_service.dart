import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/scheme.dart';
import '../models/scheme_detail.dart';

class MFApiService {
  static const String _baseUrl = 'https://api.mfapi.in';
  static const String _amfiUrl =
      'https://portal.amfiindia.com/spages/NAVAll.txt';

  static List<Scheme>? _cachedAmfiSchemes;

  final http.Client _client;

  MFApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetches and parses the AMFI NAVAll.txt file.
  /// Result is cached for the lifetime of the app — call once at startup.
  Future<List<Scheme>> loadAmfiSchemes() async {
    if (_cachedAmfiSchemes != null) return _cachedAmfiSchemes!;

    final response = await _client.get(Uri.parse(_amfiUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to load AMFI data: ${response.statusCode}');
    }

    // AMFI NAVAll.txt structure:
    //   Open Ended Schemes(Equity Scheme - Large Cap Fund)   ← category header
    //   SBI Mutual Fund                                       ← fund-house name
    //   119598;INF200K01RQ6;;SBI Bluechip Fund...;45.72;... ← scheme row
    //
    // Fields in scheme rows: code ; isin_growth ; isin_div ; name ; nav ; date
    final schemes = <Scheme>[];
    String currentCategory = '';
    String currentFundHouse = '';

    for (final rawLine in response.body.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final parts = line.split(';');
      final code = int.tryParse(parts[0].trim());

      if (code != null && parts.length >= 4) {
        // Scheme row
        final name = parts[3].trim();
        if (name.isEmpty || !_isDirectGrowth(name)) continue;
        schemes.add(Scheme(
          schemeCode: code,
          schemeName: name,
          category: currentCategory.isNotEmpty ? currentCategory : null,
          fundHouse: currentFundHouse.isNotEmpty ? currentFundHouse : null,
        ));
      } else if (parts.length == 1) {
        // Header line — no semicolons
        if (line.contains('(') && line.contains(')')) {
          // Category header: extract text inside the last pair of parentheses
          final start = line.lastIndexOf('(') + 1;
          final end = line.lastIndexOf(')');
          if (start < end) currentCategory = line.substring(start, end).trim();
          currentFundHouse = ''; // reset fund house for new category
        } else {
          // Fund-house name
          currentFundHouse = line;
        }
      }
    }

    _cachedAmfiSchemes = schemes;
    return schemes;
  }

  Future<List<Scheme>> searchSchemes(String query) async {
    final uri = Uri.parse('$_baseUrl/mf/search')
        .replace(queryParameters: {'q': query});
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Search failed: ${response.statusCode}');
    }
    final List<dynamic> json = jsonDecode(response.body) as List<dynamic>;
    return json
        .map((e) => Scheme.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SchemeDetail> getLatestNAV(int schemeCode) async {
    final uri = Uri.parse('$_baseUrl/mf/$schemeCode/latest');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to get latest NAV: ${response.statusCode}');
    }
    return SchemeDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<SchemeDetail> getNAVHistory(
    int schemeCode, {
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;

    final uri = Uri.parse('$_baseUrl/mf/$schemeCode').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to get NAV history: ${response.statusCode}');
    }
    return SchemeDetail.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Keep only Direct Plan Growth schemes; exclude IDCW / Dividend variants.
  static bool _isDirectGrowth(String name) {
    final lower = name.toLowerCase();
    return lower.contains('direct') &&
        lower.contains('growth') &&
        !lower.contains('idcw');
  }
}
