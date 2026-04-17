import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Reverse-SIP goal planner: given a target corpus, years, and expected
/// annual return, computes the required monthly SIP.
class GoalPlannerScreen extends StatefulWidget {
  const GoalPlannerScreen({super.key});

  @override
  State<GoalPlannerScreen> createState() => _GoalPlannerScreenState();
}

class _GoalPlannerScreenState extends State<GoalPlannerScreen> {
  final _inrFmt =
      NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

  final _targetCtrl = TextEditingController(text: '5000000'); // 50L
  double _years = 10;
  double _returnRate = 12; // % p.a.

  // Results
  double? _monthlySip;
  double? _totalInvested;
  double? _gains;

  @override
  void initState() {
    super.initState();
    _calculate();
    _targetCtrl.addListener(_calculate);
  }

  void _calculate() {
    final target = double.tryParse(_targetCtrl.text.replaceAll(',', ''));
    if (target == null || target <= 0) {
      setState(() => _monthlySip = null);
      return;
    }
    final n = (_years * 12).round(); // total months
    final r = _returnRate / 100 / 12; // monthly rate

    // FV of SIP = P * ((1+r)^n - 1) / r * (1+r)
    // → P = FV * r / (((1+r)^n - 1) * (1+r))
    final denom = (pow(1 + r, n) - 1) * (1 + r);
    final sip = denom == 0 ? 0.0 : target * r / denom;

    setState(() {
      _monthlySip = sip;
      _totalInvested = sip * n;
      _gains = target - sip * n;
    });
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  Widget _statRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Goal Planner'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'How much should I invest monthly to reach my goal?',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),

          // ── Inputs ────────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Target Corpus',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _targetCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      prefixText: '₹  ',
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: 'e.g. 5000000 for ₹50L',
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Time Horizon: ${_years.round()} years',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Slider(
                    value: _years,
                    min: 1,
                    max: 30,
                    divisions: 29,
                    label: '${_years.round()} yr',
                    onChanged: (v) {
                      setState(() => _years = v);
                      _calculate();
                    },
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Expected Return: ${_returnRate.toStringAsFixed(1)}% p.a.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Slider(
                    value: _returnRate,
                    min: 4,
                    max: 30,
                    divisions: 52,
                    label: '${_returnRate.toStringAsFixed(1)}%',
                    onChanged: (v) {
                      setState(() => _returnRate = v);
                      _calculate();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Results ───────────────────────────────────────────────────────
          if (_monthlySip != null) ...[
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Required Monthly SIP',
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      _inrFmt.format(_monthlySip!.round()),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer),
                    ),
                    const Divider(height: 24),
                    _statRow(
                      'Target Corpus',
                      _inrFmt.format(double.tryParse(
                              _targetCtrl.text.replaceAll(',', '')) ??
                          0),
                    ),
                    _statRow(
                      'Total Invested',
                      _inrFmt.format(_totalInvested!.round()),
                    ),
                    _statRow(
                      'Estimated Gains',
                      _inrFmt.format(_gains!.round()),
                      valueColor: Colors.green.shade700,
                    ),
                    _statRow(
                      'Duration',
                      '${_years.round()} years (${(_years * 12).round()} months)',
                    ),
                    _statRow(
                      'Assumed Return',
                      '${_returnRate.toStringAsFixed(1)}% p.a.',
                    ),
                    const SizedBox(height: 12),
                    // Proportion bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 8,
                        child: Row(children: [
                          Flexible(
                            flex: _totalInvested!.round().clamp(1, 1 << 30),
                            child: Container(
                                color: cs.primary.withValues(alpha: 0.55)),
                          ),
                          if (_gains! > 0)
                            Flexible(
                              flex: _gains!.round().clamp(1, 1 << 30),
                              child: Container(color: Colors.green.shade400),
                            ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      _dot(cs.primary.withValues(alpha: 0.55), 'Invested'),
                      const SizedBox(width: 16),
                      _dot(Colors.green.shade400, 'Gains'),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Note: This is an indicative estimate assuming a fixed '
                  '${_returnRate.toStringAsFixed(1)}% annual return with monthly '
                  'compounding. Actual mutual fund returns vary.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _dot(Color color, String label) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ]);
}
