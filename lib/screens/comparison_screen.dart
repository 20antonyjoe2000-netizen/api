import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/scheme.dart';
import '../models/nav_entry.dart';
import '../services/mf_api_service.dart';
import '../state/app_state.dart';

/// Overlays up to 3 funds' NAV history, normalized to 100 at the common
/// start date, so you can compare relative performance.
class ComparisonScreen extends StatefulWidget {
  final List<Scheme> schemes;
  const ComparisonScreen({super.key, required this.schemes});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  final _service = MFApiService();
  final _appState = AppState();

  // Per-fund state
  final Map<int, List<NavEntry>> _histories = {};
  final Map<int, bool> _loading = {};
  final Map<int, String?> _errors = {};

  String _period = '3Y'; // '1Y' | '3Y' | '5Y' | 'All'
  static const _periods = ['1Y', '3Y', '5Y', 'All'];

  static const _colors = [Colors.indigo, Colors.orange, Colors.green];

  @override
  void initState() {
    super.initState();
    for (final s in widget.schemes) {
      _fetchHistory(s.schemeCode);
    }
  }

  Future<void> _fetchHistory(int code) async {
    setState(() {
      _loading[code] = true;
      _errors[code] = null;
    });
    try {
      final detail = await _service.getNAVHistory(code);
      setState(() => _histories[code] = detail.navHistory);
    } catch (_) {
      setState(() => _errors[code] = 'Failed to load');
    } finally {
      setState(() => _loading[code] = false);
    }
  }

  DateTime _cutoff() {
    final now = DateTime.now();
    return switch (_period) {
      '1Y' => DateTime(now.year - 1, now.month, now.day),
      '3Y' => DateTime(now.year - 3, now.month, now.day),
      '5Y' => DateTime(now.year - 5, now.month, now.day),
      _ => DateTime(1970),
    };
  }

  /// Returns filtered + normalized entries (base = 100 at first point).
  List<NavEntry> _normalized(List<NavEntry> raw) {
    final cut = _cutoff();
    final filtered = raw.where((e) => !e.date.isBefore(cut)).toList();
    if (filtered.isEmpty) return [];
    final base = filtered.first.nav;
    if (base == 0) return [];
    return filtered
        .map((e) => NavEntry(date: e.date, nav: e.nav / base * 100))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final schemes = widget.schemes;
    final allReady = schemes.every(
      (s) => (_loading[s.schemeCode] ?? true) == false && _histories.containsKey(s.schemeCode),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Funds'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              _appState.clearComparison();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Legend
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (int i = 0; i < schemes.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 4,
                            color: _colors[i % _colors.length],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              schemes[i].schemeName,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_loading[schemes[i].schemeCode] == true)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _appState.removeFromComparison(schemes[i].schemeCode);
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ComparisonScreen(
                                      schemes: _appState.comparison,
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Period selector
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: _periods
                .map((p) => ButtonSegment(value: p, label: Text(p)))
                .toList(),
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          ),
          const SizedBox(height: 16),

          if (!allReady)
            const Center(child: CircularProgressIndicator())
          else
            _buildChart(schemes),

          const SizedBox(height: 16),
          _buildReturnTable(schemes),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildChart(List<Scheme> schemes) {
    final normalizedMap = <int, List<NavEntry>>{};
    for (final s in schemes) {
      final raw = _histories[s.schemeCode];
      if (raw != null) normalizedMap[s.schemeCode] = _normalized(raw);
    }

    if (normalizedMap.values.every((l) => l.isEmpty)) {
      return const Center(child: Text('No data for this period.'));
    }

    // Build time-aligned spots: use a common date set
    // Simple approach: each series uses its own x=index axis
    final bars = <LineChartBarData>[];
    double globalMaxY = 0;

    for (int i = 0; i < schemes.length; i++) {
      final entries = normalizedMap[schemes[i].schemeCode] ?? [];
      if (entries.isEmpty) continue;
      final spots = List.generate(
        entries.length,
        (j) => FlSpot(j.toDouble(), entries[j].nav),
      );
      globalMaxY = max(globalMaxY, entries.map((e) => e.nav).reduce(max));
      bars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: _colors[i % _colors.length],
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));
    }

    final maxPoints = normalizedMap.values
        .where((l) => l.isNotEmpty)
        .map((l) => l.length)
        .reduce(max);
    final step = (maxPoints / 5).ceil().clamp(1, maxPoints);

    // Use the longest series for x-axis labels
    final longestSeries = normalizedMap.values
        .where((l) => l.isNotEmpty)
        .reduce((a, b) => a.length >= b.length ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 12, bottom: 8),
              child: Text(
                'Normalized to 100 at start',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
            SizedBox(
              height: 280,
              child: LineChart(
                key: ValueKey(_period),
                LineChartData(
                  minX: 0,
                  maxX: (maxPoints - 1).toDouble(),
                  minY: 80,
                  maxY: globalMaxY * 1.05,
                  lineBarsData: bars,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: step.toDouble(),
                        getTitlesWidget: (v, _) {
                          final idx = v.round();
                          if (idx < 0 ||
                              idx >= longestSeries.length ||
                              idx % step != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              DateFormat('MMM yy')
                                  .format(longestSeries[idx].date),
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (v, _) => Text(
                          v.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Colors.black87,
                      getTooltipItems: (spots) => spots.map((s) {
                        final seriesIdx = s.barIndex;
                        final entries = normalizedMap[
                                schemes[seriesIdx].schemeCode] ??
                            [];
                        final idx = s.x.round().clamp(0, entries.length - 1);
                        return LineTooltipItem(
                          '${schemes[seriesIdx].schemeName.split(' ').take(3).join(' ')}\n'
                          '${DateFormat('dd MMM yy').format(entries[idx].date)}: ${s.y.toStringAsFixed(1)}',
                          TextStyle(
                            color: _colors[seriesIdx % _colors.length],
                            fontSize: 10,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnTable(List<Scheme> schemes) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Returns Summary',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(1),
              },
              children: [
                const TableRow(
                  decoration: BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: Colors.black12)),
                  ),
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text('Fund',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text('Return',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          textAlign: TextAlign.right),
                    ),
                  ],
                ),
                for (int i = 0; i < schemes.length; i++)
                  _returnRow(schemes[i], _colors[i % _colors.length]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TableRow _returnRow(Scheme scheme, Color color) {
    final entries = _histories[scheme.schemeCode];
    String returnStr = '—';
    Color returnColor = Colors.black54;
    if (entries != null && entries.isNotEmpty) {
      final cut = _cutoff();
      final filtered = entries.where((e) => !e.date.isBefore(cut)).toList();
      if (filtered.length >= 2) {
        final pct =
            (filtered.last.nav - filtered.first.nav) / filtered.first.nav * 100;
        returnStr = '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';
        returnColor =
            pct >= 0 ? Colors.green.shade700 : Colors.red.shade700;
      }
    }
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(width: 10, height: 10, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                scheme.schemeName,
                style: const TextStyle(fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          returnStr,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: returnColor),
          textAlign: TextAlign.right,
        ),
      ),
    ]);
  }
}
