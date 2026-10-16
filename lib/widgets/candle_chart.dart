import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/oi_profile.dart';
import '../models/option_contract.dart';

/// Price chart + horizontal OI Profile histogram.
/// Y-axis = Option Premium; right panel = OI at each premium bin.
class CandleChartWithOiProfile extends StatelessWidget {
  final OptionContract contract;
  final OiProfile profile;

  const CandleChartWithOiProfile({
    super.key,
    required this.contract,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final spots = _generateDemoSpots();
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 5;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 5;

    return Row(
      children: [
        Expanded(
          flex: 7,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: LineChart(
              LineChartData(
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: const Color(0xFF26A69A),
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF26A69A).withValues(alpha: 0.15),
                    ),
                  ),
                ],
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: minY,
                maxY: maxY,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: _OiHistogram(profile: profile),
        ),
      ],
    );
  }

  List<FlSpot> _generateDemoSpots() {
    const base = 120.0;
    return List.generate(40, (i) {
      final y = base + (i % 7) * 1.5 - 3 + ((i % 3) - 1) * 2.5;
      return FlSpot(i.toDouble(), y);
    });
  }
}

class _OiHistogram extends StatelessWidget {
  final OiProfile profile;

  const _OiHistogram({required this.profile});

  @override
  Widget build(BuildContext context) {
    final bins = profile.sortedBins;
    if (bins.isEmpty) {
      return const Center(
        child: Text(
          'OI Profile\n(waiting for ticks)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    final maxOi = profile.maxOi;

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(4),
          child: Text(
            'OI Profile',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: bins.length,
            itemBuilder: (ctx, i) {
              final entry = bins[i];
              final premium = entry.key;
              final oi = entry.value;
              final widthFactor = maxOi > 0 ? oi / maxOi : 0.0;
              final isPoc = premium == profile.poc;
              final isHoin = profile.highOiNodes.contains(premium);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        premium.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 10,
                          color: isPoc
                              ? Colors.amber
                              : isHoin
                                  ? Colors.redAccent
                                  : Colors.grey,
                          fontWeight:
                              isPoc ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    Expanded(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: widthFactor.clamp(0.05, 1.0),
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: isPoc
                                ? Colors.amber.withValues(alpha: 0.8)
                                : isHoin
                                    ? Colors.redAccent.withValues(alpha: 0.7)
                                    : Colors.blueAccent.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
