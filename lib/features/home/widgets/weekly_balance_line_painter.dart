import 'package:flutter/material.dart';

import '../../../data/money_manager_repository.dart';
import 'weekly_balance_chart_geometry.dart';

class WeeklyBalanceLinePainter extends CustomPainter {
  WeeklyBalanceLinePainter({
    required this.points,
    required this.selectedIndex,
    required this.color,
    required this.gridColor,
    required this.surfaceColor,
  });

  final List<BalancePoint> points;
  final int? selectedIndex;
  final Color color;
  final Color gridColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }

    final geometry = WeeklyBalanceChartGeometry.fromSize(
      size: size,
      points: points,
    );

    final backgroundPaint = Paint()..color = surfaceColor;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final dotPaint = Paint()..color = color;

    canvas.drawRRect(
      RRect.fromRectAndRadius(geometry.chartRect, const Radius.circular(16)),
      backgroundPaint,
    );

    for (var index = 0; index < 4; index++) {
      final y = geometry.chartRect.top + (geometry.chartRect.height / 3) * index;
      canvas.drawLine(
        Offset(geometry.chartRect.left, y),
        Offset(geometry.chartRect.right, y),
        gridPaint,
      );
    }

    final offsets = <Offset>[];
    for (var index = 0; index < points.length; index++) {
      offsets.add(geometry.pointOffset(index, points[index].balance, points.length));
    }

    if (offsets.length > 1) {
      final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final offset in offsets.skip(1)) {
        linePath.lineTo(offset.dx, offset.dy);
      }
      canvas.drawPath(linePath, linePaint);

      final areaPath = Path()..moveTo(offsets.first.dx, geometry.chartRect.bottom);
      areaPath.lineTo(offsets.first.dx, offsets.first.dy);
      for (final offset in offsets.skip(1)) {
        areaPath.lineTo(offset.dx, offset.dy);
      }
      areaPath.lineTo(offsets.last.dx, geometry.chartRect.bottom);
      areaPath.close();
      canvas.drawPath(areaPath, fillPaint);
    }

    for (final offset in offsets) {
      canvas.drawCircle(offset, 5.5, dotPaint);
      canvas.drawCircle(offset, 2.5, Paint()..color = Colors.white);
    }

    if (selectedIndex != null && selectedIndex! >= 0 && selectedIndex! < offsets.length) {
      final selectedOffset = offsets[selectedIndex!];
      canvas.drawCircle(selectedOffset, 10, Paint()..color = color.withValues(alpha: 0.18));
      canvas.drawCircle(
        selectedOffset,
        7,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(selectedOffset, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WeeklyBalanceLinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.color != color ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.surfaceColor != surfaceColor;
  }
}
