import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/scheme.dart';
import '../models/scheme_detail.dart';
import '../models/nav_entry.dart';
import '../services/mf_api_service.dart';
import '../state/app_state.dart';
import 'sip_calculator_screen.dart';
import 'comparison_screen.dart';

enum DateRange { oneMonth, threeMonths, sixMonths, oneYear, all }

class SchemeDetailScreen extends StatefulWidget {
  final int schemeCode;

  const SchemeDetailScreen({super.key, required this.schemeCode});

  @override
  State<SchemeDetailScreen> createState() => _SchemeDetailScreenState();
}

class _SchemeDetailScreenState extends State<SchemeDetailScreen> {
  final _service = MFApiService();
  final _appState = AppState();
  final _displayDateFmt = DateFormat('dd MMM yyyy');
  final _chartKey = GlobalKey();

  SchemeDetail? _detail;
  SchemeDetail? _history;
  bool _loadingDetail = true;
  bool _loadingHistory = true;
  String? _detailError;
  String? _historyError;
  DateRange _selectedRange = DateRange.oneYear;
  bool _showTable = false;

  Scheme get _scheme => Scheme(
        schemeCode: _detail?.meta.schemeCode ?? widget.schemeCode,
        schemeName: _detail?.meta.schemeName ?? '',
        fundHouse: _detail?.meta.fundHouse,
        category: _detail?.meta.schemeCategory,
      );

  @override
  void initState() {
    super.initState();
    _loadLatest();
    _loadHistory();
  }

  Future<void> _loadLatest() async {
    setState(() {
      _loadingDetail = true;
      _detailError = null;
    });
    try {
      final d = await _service.getLatestNAV(widget.schemeCode);
      setState(() => _detail = d);
    } catch (_) {
      setState(
          () => _detailError = 'Could not load fund details. Check your connection.');
    } finally {
      setState(() => _loadingDetail = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final h = await _service.getNAVHistory(widget.schemeCode);
      setState(() => _history = h);
    } catch (_) {
      setState(
          () => _historyError = 'Could not load NAV history. Check your connection.');
    } finally {
      setState(() => _loadingHistory = false);
    }
  }

  List<NavEntry> _filteredEntries() {
    if (_history == null) return [];
    final all = _history!.navHistory;
    if (_selectedRange == DateRange.all) return all;
    final now = DateTime.now();
    final DateTime cutoff;
    switch (_selectedRange) {
      case DateRange.oneMonth:
        cutoff = DateTime(now.year, now.month - 1, now.day);
      case DateRange.threeMonths:
        cutoff = DateTime(now.year, now.month - 3, now.day);
      case DateRange.sixMonths:
        cutoff = DateTime(now.year, now.month - 6, now.day);
      case DateRange.oneYear:
        cutoff = DateTime(now.year - 1, now.month, now.day);
      case DateRange.all:
        cutoff = DateTime(1970);
    }
    return all.where((e) => e.date.isAfter(cutoff)).toList();
  }

  // ── Chart ─────────────────────────────────────────────────────────────────

  List<FlSpot> _buildSpots(List<NavEntry> entries) {
    return List.generate(
        entries.length, (i) => FlSpot(i.toDouble(), entries[i].nav));
  }

  LineChartData _buildChartData(List<NavEntry> entries) {
    final spots = _buildSpots(entries);
    final navValues = entries.map((e) => e.nav);
    final maxY = navValues.reduce((a, b) => a > b ? a : b);
    final minY = navValues.reduce((a, b) => a < b ? a : b);
    final yPadding = (maxY - minY) * 0.1;
    final step = (entries.length / 6).ceil().clamp(1, entries.length);

    return LineChartData(
      minY: minY - yPadding,
      maxY: maxY + yPadding,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Theme.of(context).colorScheme.primary,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          ),
        ),
      ],
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: step.toDouble(),
            getTitlesWidget: (value, meta) {
              final idx = value.round();
              if (idx < 0 || idx >= entries.length || idx % step != 0) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(DateFormat('MMM yy').format(entries[idx].date),
                    style: const TextStyle(fontSize: 10)),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 60,
            getTitlesWidget: (value, meta) => Text(
              '₹${value.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => Colors.black87,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final idx = spot.x.round().clamp(0, entries.length - 1);
              final entry = entries[idx];
              return LineTooltipItem(
                '${_displayDateFmt.format(entry.date)}\n₹${entry.nav.toStringAsFixed(4)}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            }).toList();
          },
        ),
      ),
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: true),
    );
  }

  // ── Share chart screenshot ────────────────────────────────────────────────

  Future<void> _shareChart() async {
    try {
      final boundary = _chartKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final name = _detail?.meta.schemeName ?? 'fund';
      await Share.shareXFiles(
        [
          XFile.fromData(bytes,
              name: '${name.replaceAll(' ', '_')}_nav.png',
              mimeType: 'image/png')
        ],
        text: 'NAV chart – $name',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not share chart.')),
        );
      }
    }
  }

  // ── 52-week high / low ────────────────────────────────────────────────────

  Widget _build52WeekCard() {
    if (_history == null) return const SizedBox.shrink();
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    final year =
        _history!.navHistory.where((e) => e.date.isAfter(cutoff)).toList();
    if (year.isEmpty) return const SizedBox.shrink();

    final high = year.map((e) => e.nav).reduce(max);
    final low = year.map((e) => e.nav).reduce(min);
    final current = _history!.navHistory.last.nav;
    final pctFromHigh = (current - high) / high * 100;
    final pctFromLow = (current - low) / low * 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('52-Week Range',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _statBox(
                        '52W Low', '₹${low.toStringAsFixed(2)}',
                        sub:
                            '${pctFromLow >= 0 ? '+' : ''}${pctFromLow.toStringAsFixed(1)}% from low',
                        color: Colors.green.shade700)),
                const SizedBox(width: 8),
                Expanded(
                    child: _statBox(
                        '52W High', '₹${high.toStringAsFixed(2)}',
                        sub:
                            '${pctFromHigh.toStringAsFixed(1)}% from high',
                        color: Colors.red.shade700)),
              ],
            ),
            const SizedBox(height: 10),
            // Range bar
            LayoutBuilder(builder: (_, c) {
              final frac = low == high ? 1.0 : (current - low) / (high - low);
              return Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: Colors.grey.shade300,
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: frac.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Risk Metrics ──────────────────────────────────────────────────────────

  /// Annualised std-dev of daily returns (volatility), %.
  double? _volatility(List<NavEntry> entries) {
    if (entries.length < 30) return null;
    final returns = <double>[];
    for (int i = 1; i < entries.length; i++) {
      if (entries[i - 1].nav > 0) {
        returns.add((entries[i].nav - entries[i - 1].nav) / entries[i - 1].nav);
      }
    }
    if (returns.length < 2) return null;
    final mean = returns.reduce((a, b) => a + b) / returns.length;
    final variance =
        returns.map((r) => pow(r - mean, 2)).reduce((a, b) => a + b) /
            returns.length;
    // Annualise: approx 252 trading days
    return sqrt(variance) * sqrt(252) * 100;
  }

  /// Maximum drawdown %, full history.
  double? _maxDrawdown(List<NavEntry> entries) {
    if (entries.length < 2) return null;
    double peak = entries.first.nav;
    double maxDD = 0;
    for (final e in entries) {
      if (e.nav > peak) peak = e.nav;
      final dd = peak > 0 ? (peak - e.nav) / peak : 0.0;
      if (dd > maxDD) maxDD = dd;
    }
    return maxDD * 100;
  }

  /// CAGR over a span.
  double? _cagr(List<NavEntry> entries, int years) {
    final cutoff = entries.last.date.subtract(Duration(days: years * 365));
    final sub = entries.where((e) => e.date.isAfter(cutoff)).toList();
    if (sub.length < 2) return null;
    final n = sub.last.date.difference(sub.first.date).inDays / 365.0;
    if (n < 0.5) return null;
    return (pow(sub.last.nav / sub.first.nav, 1 / n) - 1) * 100;
  }

  Widget _buildRiskCard() {
    if (_history == null || _loadingHistory) return const SizedBox.shrink();
    final entries = _history!.navHistory;
    final vol = _volatility(entries);
    final dd = _maxDrawdown(entries);
    final cagr1 = _cagr(entries, 1);
    final cagr3 = _cagr(entries, 3);
    final cagr5 = _cagr(entries, 5);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Performance & Risk',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (cagr1 != null)
                  _statBox('1Y CAGR', '${cagr1.toStringAsFixed(1)}%',
                      color: cagr1 >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700),
                if (cagr3 != null)
                  _statBox('3Y CAGR', '${cagr3.toStringAsFixed(1)}%',
                      color: cagr3 >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700),
                if (cagr5 != null)
                  _statBox('5Y CAGR', '${cagr5.toStringAsFixed(1)}%',
                      color: cagr5 >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700),
                if (vol != null)
                  _statBox('Volatility', '${vol.toStringAsFixed(1)}%',
                      sub: 'annualised',
                      color: vol > 20
                          ? Colors.red.shade700
                          : Colors.orange.shade700),
                if (dd != null)
                  _statBox('Max Drawdown', '-${dd.toStringAsFixed(1)}%',
                      color: Colors.red.shade700),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Rolling Returns ───────────────────────────────────────────────────────

  /// Builds rolling n-year CAGR series: for each point in navHistory that has
  /// data n years back, compute the CAGR.
  List<FlSpot> _rollingCagr(List<NavEntry> entries, int years) {
    final result = <FlSpot>[];
    final daysBack = years * 365;
    for (int i = 0; i < entries.length; i++) {
      final target = entries[i].date.subtract(Duration(days: daysBack));
      // Find closest entry at or before target
      NavEntry? past;
      for (int j = i - 1; j >= 0; j--) {
        if (!entries[j].date.isAfter(target)) {
          past = entries[j];
          break;
        }
      }
      if (past == null || past.nav == 0) continue;
      final n =
          entries[i].date.difference(past.date).inDays / 365.0;
      if (n < years * 0.8) continue;
      final cagr = (pow(entries[i].nav / past.nav, 1 / n) - 1) * 100;
      result.add(FlSpot(i.toDouble(), cagr.toDouble()));
    }
    return result;
  }

  Widget _buildRollingReturnsCard() {
    if (_history == null || _loadingHistory) return const SizedBox.shrink();
    final entries = _history!.navHistory;
    if (entries.length < 365) return const SizedBox.shrink();

    const colors = [Colors.indigo, Colors.green, Colors.orange];
    const labels = ['1Y', '3Y', '5Y'];
    const years = [1, 3, 5];

    final bars = <LineChartBarData>[];
    double minY = 0, maxY = 0;

    for (int k = 0; k < years.length; k++) {
      final spots = _rollingCagr(entries, years[k]);
      if (spots.isEmpty) continue;
      bars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: colors[k],
        barWidth: 1.5,
        dotData: const FlDotData(show: false),
      ));
      for (final s in spots) {
        if (s.y < minY) minY = s.y;
        if (s.y > maxY) maxY = s.y;
      }
    }

    if (bars.isEmpty) return const SizedBox.shrink();

    final n = entries.length;
    final step = (n / 5).ceil().clamp(1, n);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text('Rolling Returns',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Wrap(
                spacing: 12,
                children: [
                  for (int k = 0; k < labels.length; k++)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 14,
                          height: 3,
                          color: colors[k]),
                      const SizedBox(width: 4),
                      Text(labels[k],
                          style: const TextStyle(fontSize: 11)),
                    ]),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (n - 1).toDouble(),
                  minY: minY - 2,
                  maxY: maxY + 2,
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
                              idx >= n ||
                              idx % step != 0) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              DateFormat('MMM yy')
                                  .format(entries[idx].date),
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text(
                          '${v.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                          y: 0,
                          color: Colors.black26,
                          strokeWidth: 1,
                          dashArray: [4, 4]),
                    ],
                  ),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _statBox(String label, String value,
      {String? sub, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
          Text(
            value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color),
          ),
          if (sub != null)
            Text(sub,
                style: const TextStyle(fontSize: 10, color: Colors.black45)),
        ],
      ),
    );
  }

  Widget _buildFilterButtons() {
    const labels = {
      DateRange.oneMonth: '1M',
      DateRange.threeMonths: '3M',
      DateRange.sixMonths: '6M',
      DateRange.oneYear: '1Y',
      DateRange.all: 'All',
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: DateRange.values.map((r) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FilterChip(
            label: Text(labels[r]!),
            selected: r == _selectedRange,
            onSelected: (_) => setState(() => _selectedRange = r),
          ),
        );
      }).toList(),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildMetaCard() {
    if (_loadingDetail) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_detailError != null) {
      return Center(
        child: Text(_detailError!,
            style:
                TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center),
      );
    }
    final meta = _detail!.meta;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(meta.schemeName,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            _metaRow('Fund House', meta.fundHouse),
            _metaRow('Type', meta.schemeType),
            _metaRow('Category', meta.schemeCategory),
            _metaRow('ISIN (Growth)', meta.isinGrowth ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestNavSection() {
    if (_loadingDetail || _detail?.latestNav == null) {
      return const SizedBox.shrink();
    }
    final nav = _detail!.latestNav!;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Latest NAV',
                style: Theme.of(context).textTheme.titleMedium),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${nav.nav.toStringAsFixed(4)}',
                  style:
                      Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                ),
                Text(_displayDateFmt.format(nav.date),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    final entries = _filteredEntries().reversed.toList();
    return SizedBox(
      height: 300,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('NAV (₹)'), numeric: true),
          ],
          rows: entries
              .map((e) => DataRow(cells: [
                    DataCell(Text(_displayDateFmt.format(e.date))),
                    DataCell(Text(e.nav.toStringAsFixed(4))),
                  ]))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    final entries = _filteredEntries();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('NAV History',
                style: Theme.of(context).textTheme.titleMedium),
            if (!_loadingHistory && entries.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share chart',
                onPressed: _shareChart,
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildFilterButtons(),
        const SizedBox(height: 8),
        if (_loadingHistory)
          const Center(child: CircularProgressIndicator())
        else if (_historyError != null)
          Center(
            child: Text(_historyError!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center),
          )
        else if (entries.isEmpty)
          const Center(child: Text('No data available for this range.'))
        else ...[
          RepaintBoundary(
            key: _chartKey,
            child: SizedBox(
              height: 280,
              child: LineChart(
                key: ValueKey(_selectedRange),
                _buildChartData(entries),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => setState(() => _showTable = !_showTable),
            icon:
                Icon(_showTable ? Icons.expand_less : Icons.expand_more),
            label: Text(
                _showTable ? 'Hide Data Table' : 'View Data Table'),
          ),
          if (_showTable) _buildDataTable(),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFav = _appState.isFavourite(widget.schemeCode);
    final inCompare = _appState.inComparison(widget.schemeCode);

    return Scaffold(
      appBar: AppBar(
        title: Text(_detail?.meta.schemeName ?? 'Fund Detail'),
        centerTitle: true,
        actions: [
          // Compare toggle
          IconButton(
            icon: Icon(
              inCompare ? Icons.compare_arrows : Icons.compare_arrows_outlined,
              color: inCompare
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: inCompare ? 'Remove from compare' : 'Add to compare',
            onPressed: () {
              if (_detail == null) return;
              if (inCompare) {
                _appState.removeFromComparison(widget.schemeCode);
              } else {
                final added = _appState.addToComparison(_scheme);
                if (!added) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Compare supports up to 3 funds.')),
                  );
                }
              }
              setState(() {});
            },
          ),
          // Favourite toggle
          IconButton(
            icon: Icon(isFav ? Icons.star : Icons.star_outline,
                color: isFav ? Colors.amber : null),
            tooltip: isFav ? 'Remove from watchlist' : 'Add to watchlist',
            onPressed: () {
              if (_detail == null) return;
              _appState.toggleFavourite(_scheme);
              setState(() {});
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetaCard(),
            const SizedBox(height: 16),
            _buildLatestNavSection(),
            const SizedBox(height: 16),
            _build52WeekCard(),
            const SizedBox(height: 16),
            _buildRiskCard(),
            const SizedBox(height: 16),
            _buildHistorySection(),
            const SizedBox(height: 16),
            _buildRollingReturnsCard(),
            const SizedBox(height: 16),
            if (_detail != null && _history != null) ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SipCalculatorScreen(
                            schemeName: _detail!.meta.schemeName,
                            navHistory: _history!.navHistory,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text('SIP Calculator'),
                    ),
                  ),
                ],
              ),
              if (_appState.comparison.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ComparisonScreen(
                            schemes: _appState.comparison),
                      ),
                    ).then((_) => setState(() {})),
                    icon: const Icon(Icons.compare_arrows),
                    label: Text(
                        'View Comparison (${_appState.comparison.length})'),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
