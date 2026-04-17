import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/nav_entry.dart';
import 'goal_planner_screen.dart';

// One SIP instalment simulated against real NAV data
class _Instalment {
  final DateTime date;
  final double nav;
  final double amount;
  final double units;
  final double cumUnits;
  final double cumInvested;
  final double portfolioValue;

  const _Instalment({
    required this.date,
    required this.nav,
    required this.amount,
    required this.units,
    required this.cumUnits,
    required this.cumInvested,
    required this.portfolioValue,
  });
}

class SipCalculatorScreen extends StatefulWidget {
  final String schemeName;
  final List<NavEntry> navHistory;

  const SipCalculatorScreen({
    super.key,
    required this.schemeName,
    required this.navHistory,
  });

  @override
  State<SipCalculatorScreen> createState() => _SipCalculatorScreenState();
}

class _SipCalculatorScreenState extends State<SipCalculatorScreen> {
  final _inrFmt =
      NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');
  final _amountCtrl = TextEditingController(text: '5000');

  int _sipDay = 1;
  String _period = '3Y';
  double _stepUpPct = 0; // annual step-up %
  bool _showTable = false;

  List<_Instalment> _instalments = [];

  static const _periods = ['1Y', '3Y', '5Y', '10Y', '15Y', 'All'];
  static const _sipDays = [1, 5, 10, 15, 20, 25];

  @override
  void initState() {
    super.initState();
    _simulate();
  }

  // ── Core simulation ────────────────────────────────────────────────────────

  void _simulate() {
    final history = widget.navHistory;
    if (history.isEmpty) return;

    final baseAmount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 5000;
    if (baseAmount <= 0) return;

    final latestDate = history.last.date;
    final startDate = _periodStart(latestDate);

    final result = <_Instalment>[];
    double cumUnits = 0, cumInvested = 0;

    DateTime sipDate = DateTime(startDate.year, startDate.month, _sipDay);
    if (sipDate.isBefore(startDate)) {
      sipDate = DateTime(startDate.year, startDate.month + 1, _sipDay);
    }

    int monthCount = 0;
    while (!sipDate.isAfter(latestDate)) {
      final entry = _navOnOrAfter(sipDate, history);
      if (entry != null) {
        // Step-up: increase by _stepUpPct every 12 months
        final yearsPassed = monthCount ~/ 12;
        final amount = baseAmount * pow(1 + _stepUpPct / 100, yearsPassed);
        final units = amount / entry.nav;
        cumUnits += units;
        cumInvested += amount;
        result.add(_Instalment(
          date: entry.date,
          nav: entry.nav,
          amount: amount,
          units: units,
          cumUnits: cumUnits,
          cumInvested: cumInvested,
          portfolioValue: cumUnits * entry.nav,
        ));
      }
      sipDate = DateTime(sipDate.year, sipDate.month + 1, _sipDay);
      monthCount++;
    }

    setState(() => _instalments = result);
  }

  DateTime _periodStart(DateTime latestDate) {
    return switch (_period) {
      '1Y'  => DateTime(latestDate.year - 1,  latestDate.month, latestDate.day),
      '3Y'  => DateTime(latestDate.year - 3,  latestDate.month, latestDate.day),
      '5Y'  => DateTime(latestDate.year - 5,  latestDate.month, latestDate.day),
      '10Y' => DateTime(latestDate.year - 10, latestDate.month, latestDate.day),
      '15Y' => DateTime(latestDate.year - 15, latestDate.month, latestDate.day),
      _ => widget.navHistory.first.date,
    };
  }

  NavEntry? _navOnOrAfter(DateTime target, List<NavEntry> history) {
    for (final e in history) {
      if (!e.date.isBefore(target)) return e;
    }
    return null;
  }

  // ── Derived results ────────────────────────────────────────────────────────

  double get _currentNav =>
      widget.navHistory.isNotEmpty ? widget.navHistory.last.nav : 0;

  double get _presentValue =>
      _instalments.isNotEmpty ? _instalments.last.cumUnits * _currentNav : 0;

  double get _totalInvested =>
      _instalments.isNotEmpty ? _instalments.last.cumInvested : 0;

  double get _absoluteReturn => _presentValue - _totalInvested;

  double get _absoluteReturnPct =>
      _totalInvested > 0 ? (_absoluteReturn / _totalInvested) * 100 : 0;

  double? get _xirr {
    if (_instalments.length < 2) return null;
    final baseDate = _instalments.first.date;
    final flows = <(double, double)>[
      ..._instalments
          .map((i) => (i.date.difference(baseDate).inDays / 365.0, -i.amount)),
      (widget.navHistory.last.date.difference(baseDate).inDays / 365.0,
          _presentValue),
    ];
    double r = 0.1;
    for (int iter = 0; iter < 300; iter++) {
      double f = 0, df = 0;
      for (final (t, c) in flows) {
        final denom = pow(1 + r, t);
        f += c / denom;
        df -= t * c / (denom * (1 + r));
      }
      if (df.abs() < 1e-12) break;
      final delta = f / df;
      r -= delta;
      r = r.clamp(-0.9999, 50.0);
      if (delta.abs() < 1e-8) break;
    }
    return r * 100;
  }

  // ── Lumpsum comparison ─────────────────────────────────────────────────────

  /// What would a lumpsum of [_totalInvested] on the first SIP date be worth?
  double? get _lumpsumValue {
    if (_instalments.isEmpty || _currentNav == 0) return null;
    final firstNav = _instalments.first.nav;
    if (firstNav == 0) return null;
    return _totalInvested / firstNav * _currentNav;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _compact(double v) {
    if (v >= 1e7) return '₹${(v / 1e7).toStringAsFixed(2)}Cr';
    if (v >= 1e5) return '₹${(v / 1e5).toStringAsFixed(2)}L';
    if (v >= 1e3) return '₹${(v / 1e3).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  String _fmtDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);
  String _fmtMonthYear(DateTime d) => DateFormat('MMM yy').format(d);

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monthly SIP Amount',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => _simulate(),
              decoration: const InputDecoration(
                prefixText: '₹  ',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            Text('Annual Step-Up: ${_stepUpPct.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.bodyMedium),
            Slider(
              value: _stepUpPct,
              min: 0,
              max: 25,
              divisions: 25,
              label: '${_stepUpPct.toStringAsFixed(0)}%',
              onChanged: (v) {
                setState(() => _stepUpPct = v);
                _simulate();
              },
            ),
            const SizedBox(height: 4),

            Text('SIP Date (day of month)',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _sipDays.map((d) {
                final selected = d == _sipDay;
                return ChoiceChip(
                  label: Text('${d}th'),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _sipDay = d);
                    _simulate();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            Text('Investment Period',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: _periods
                    .map((p) => ButtonSegment(value: p, label: Text(p)))
                    .toList(),
                selected: {_period},
                onSelectionChanged: (s) {
                  setState(() => _period = s.first);
                  _simulate();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    if (_instalments.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Not enough NAV data for this period.')),
        ),
      );
    }

    final xirr = _xirr;
    final isPositive = _absoluteReturn >= 0;
    final returnColor =
        isPositive ? Colors.green.shade700 : Colors.red.shade700;
    final cs = Theme.of(context).colorScheme;
    final lumpsum = _lumpsumValue;

    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_instalments.length} instalments',
                    style: Theme.of(context).textTheme.bodySmall),
                Text(
                  '${_fmtDate(_instalments.first.date)} → ${_fmtDate(_instalments.last.date)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (_stepUpPct > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Step-up: ${_stepUpPct.toStringAsFixed(0)}% per year',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
            const Divider(height: 20),
            _row('Total Invested', _inrFmt.format(_totalInvested)),
            _row('Present Value', _inrFmt.format(_presentValue),
                highlight: true),
            _row(
              'Absolute Return',
              '${isPositive ? '+' : ''}${_inrFmt.format(_absoluteReturn)}  (${_absoluteReturnPct.toStringAsFixed(1)}%)',
              valueColor: returnColor,
            ),
            if (xirr != null)
              _row('XIRR', '${xirr.toStringAsFixed(2)}% p.a.',
                  valueColor: returnColor),

            // Lumpsum comparison
            if (lumpsum != null) ...[
              const Divider(height: 20),
              Text('vs. Lumpsum (same amount on day 1)',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              _row('Lumpsum Value', _inrFmt.format(lumpsum)),
              _row(
                'Difference (SIP − LS)',
                '${(_presentValue - lumpsum) >= 0 ? '+' : ''}${_inrFmt.format(_presentValue - lumpsum)}',
                valueColor: (_presentValue - lumpsum) >= 0
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
            ],

            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(children: [
                  Flexible(
                    flex: _totalInvested.round().clamp(1, 1 << 30),
                    child:
                        Container(color: cs.primary.withValues(alpha: 0.55)),
                  ),
                  if (_absoluteReturn > 0)
                    Flexible(
                      flex: _absoluteReturn.round().clamp(1, 1 << 30),
                      child: Container(color: Colors.green.shade400),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _dot(cs.primary.withValues(alpha: 0.55), 'Invested'),
              if (_absoluteReturn > 0) _dot(Colors.green.shade400, 'Gains'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (_instalments.length < 2) return const SizedBox.shrink();

    final valueSpots = List.generate(
      _instalments.length,
      (i) => FlSpot(i.toDouble(), _instalments[i].portfolioValue),
    );
    final investedSpots = List.generate(
      _instalments.length,
      (i) => FlSpot(i.toDouble(), _instalments[i].cumInvested),
    );

    // Lumpsum line
    final lumpsum = _lumpsumValue;
    List<FlSpot>? lumpsumSpots;
    if (lumpsum != null && _instalments.isNotEmpty) {
      final firstNav = _instalments.first.nav;
      if (firstNav > 0) {
        final units = _totalInvested / firstNav;
        lumpsumSpots = List.generate(
          _instalments.length,
          (i) => FlSpot(i.toDouble(), units * _instalments[i].nav),
        );
      }
    }

    final maxY = [
      ..._instalments.map((e) => e.portfolioValue),
      if (lumpsumSpots != null) ...lumpsumSpots.map((s) => s.y),
    ].reduce(max) * 1.1;
    final n = _instalments.length;
    final step = (n / 5).ceil().clamp(1, n);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text('Portfolio Value (actual NAV data)',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              children: [
                _legend(Colors.green, 'SIP Value'),
                _legend(Theme.of(context).colorScheme.primary, 'Invested',
                    dashed: true),
                if (lumpsumSpots != null)
                  _legend(Colors.orange, 'Lumpsum Value', dashed: true),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: LineChart(
                key: ValueKey(
                    '${_period}_${_sipDay}_${_amountCtrl.text}_$_stepUpPct'),
                LineChartData(
                  minX: 0,
                  maxX: (n - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: valueSpots,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withValues(alpha: 0.08),
                      ),
                    ),
                    LineChartBarData(
                      spots: investedSpots,
                      isCurved: false,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      dashArray: [6, 4],
                    ),
                    if (lumpsumSpots != null)
                      LineChartBarData(
                        spots: lumpsumSpots,
                        isCurved: true,
                        color: Colors.orange,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        dashArray: [4, 3],
                      ),
                  ],
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
                              _fmtMonthYear(_instalments[idx].date),
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (v, _) => Text(
                          _compact(v),
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Colors.black87,
                      getTooltipItems: (spots) => spots.map((s) {
                        final idx = s.x.round().clamp(0, n - 1);
                        final inst = _instalments[idx];
                        final labels = ['SIP', 'Invested', 'Lumpsum'];
                        final colors = [
                          Colors.greenAccent,
                          Colors.lightBlueAccent,
                          Colors.orange.shade200,
                        ];
                        return LineTooltipItem(
                          '${_fmtDate(inst.date)}\n'
                          '${labels[s.barIndex]}: ${_compact(s.y)}',
                          TextStyle(
                            color: colors[s.barIndex % colors.length],
                            fontSize: 11,
                          ),
                        );
                      }).toList(),
                    ),
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

  Widget _buildTableToggle() {
    if (_instalments.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _showTable = !_showTable),
          icon: Icon(_showTable ? Icons.expand_less : Icons.expand_more),
          label: Text(_showTable
              ? 'Hide Monthly Breakdown'
              : 'View Monthly Breakdown'),
        ),
        if (_showTable) _buildTable(),
      ],
    );
  }

  Widget _buildTable() {
    final reversed = _instalments.reversed.toList();
    return SizedBox(
      height: 320,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 12,
          headingRowHeight: 36,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 36,
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('SIP ₹'), numeric: true),
            DataColumn(label: Text('NAV'), numeric: true),
            DataColumn(label: Text('Value'), numeric: true),
          ],
          rows: reversed.map((i) {
            return DataRow(cells: [
              DataCell(Text(DateFormat('dd MMM yy').format(i.date),
                  style: const TextStyle(fontSize: 12))),
              DataCell(Text(_compact(i.amount),
                  style: const TextStyle(fontSize: 12))),
              DataCell(Text(i.nav.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 12))),
              DataCell(Text(_compact(i.portfolioValue),
                  style: const TextStyle(fontSize: 12))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // ── Small helpers ──────────────────────────────────────────────────────────

  Widget _row(String label, String value,
      {bool highlight = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight:
                      highlight ? FontWeight.bold : FontWeight.w500,
                  color: valueColor ??
                      (highlight
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : null),
                ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color, String label) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ]);

  Widget _legend(Color color, String label, {bool dashed = false}) => Row(
        children: [
          SizedBox(
            width: 28,
            height: 16,
            child: CustomPaint(
                painter: _LinePainter(color: color, dashed: dashed)),
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SIP Calculator'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Goal Planner',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const GoalPlannerScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.schemeName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Returns calculated using actual NAV data',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 12),
          _buildInputCard(),
          const SizedBox(height: 12),
          _buildResultsCard(),
          const SizedBox(height: 12),
          _buildChart(),
          const SizedBox(height: 4),
          _buildTableToggle(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }
}

class _LinePainter extends CustomPainter {
  final Color color;
  final bool dashed;
  const _LinePainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    const dash = 5.0, gap = 3.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y),
          Offset((x + dash).clamp(0, size.width), y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.color != color || old.dashed != dashed;
}
