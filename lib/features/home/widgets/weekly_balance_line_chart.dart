import 'package:flutter/material.dart';

import '../../../core/currency_formatter.dart';
import '../../../data/money_manager_repository.dart';
import 'weekly_balance_chart_geometry.dart';
import 'weekly_balance_line_painter.dart';

class WeeklyBalanceLineChart extends StatefulWidget {
  const WeeklyBalanceLineChart({super.key, required this.points});

  final List<BalancePoint> points;

  @override
  State<WeeklyBalanceLineChart> createState() => WeeklyBalanceLineChartState();
}

class WeeklyBalanceLineChartState extends State<WeeklyBalanceLineChart> {
  int? _selectedIndex;

  void _handleTapDown(TapDownDetails details, Size size) {
    final geometry = WeeklyBalanceChartGeometry.fromSize(
      size: size,
      points: widget.points,
    );

    setState(() {
      _selectedIndex = geometry.nearestIndex(details.localPosition, widget.points);
    });
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.points.map((point) => point.label).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartSize = Size(constraints.maxWidth, 120);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      key: const Key('weekly-balance-chart'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) => _handleTapDown(details, chartSize),
                      child: CustomPaint(
                        size: chartSize,
                        painter: WeeklyBalanceLinePainter(
                          points: widget.points,
                          selectedIndex: _selectedIndex,
                          color: Theme.of(context).colorScheme.primary,
                          gridColor: Theme.of(context).colorScheme.outlineVariant,
                          surfaceColor: Theme.of(context).colorScheme.surface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: labels
                        .map(
                          (label) => SizedBox(
                            width: 36,
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedIndex == null
                        ? 'Tap a point to inspect its balance.'
                        : 'Selected: ${widget.points[_selectedIndex!].label} · ${formatCurrency(widget.points[_selectedIndex!].balance)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
