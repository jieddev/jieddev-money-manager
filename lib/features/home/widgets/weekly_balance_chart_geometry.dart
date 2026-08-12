import 'package:flutter/material.dart';

import '../../../data/money_manager_repository.dart';

class WeeklyBalanceChartGeometry {
  WeeklyBalanceChartGeometry({
    required this.chartRect,
    required this.minBalance,
    required this.effectiveRange,
  });

  factory WeeklyBalanceChartGeometry.fromSize({
    required Size size,
    required List<BalancePoint> points,
  }) {
    final chartRect = Rect.fromLTWH(12, 8, size.width - 24, size.height - 16);
    final minBalance = points.map((point) => point.balance).reduce((a, b) => a < b ? a : b);
    final maxBalance = points.map((point) => point.balance).reduce((a, b) => a > b ? a : b);
    final balanceRange = (maxBalance - minBalance).abs();
    return WeeklyBalanceChartGeometry(
      chartRect: chartRect,
      minBalance: minBalance,
      effectiveRange: balanceRange == 0 ? 1 : balanceRange,
    );
  }

  final Rect chartRect;
  final int minBalance;
  final int effectiveRange;

  Offset pointOffset(int index, int balance, int count) {
    final horizontalStep = count == 1 ? 0.0 : chartRect.width / (count - 1);
    final x = chartRect.left + horizontalStep * index;
    final normalized = (balance - minBalance) / effectiveRange;
    final y = chartRect.bottom - (normalized * chartRect.height);
    return Offset(x, y);
  }

  int nearestIndex(Offset localPosition, List<BalancePoint> points) {
    var nearest = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < points.length; index++) {
      final point = pointOffset(index, points[index].balance, points.length);
      final distance = (point - localPosition).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = index;
      }
    }
    return nearest;
  }
}
