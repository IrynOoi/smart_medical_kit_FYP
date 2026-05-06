//curved_chart_painter.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';


class CurvedChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> labels;
  final Color lineColor;
  final int selectedIndex;

  CurvedChartPainter({
    required this.data,
    required this.labels,
    required this.lineColor,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || labels.isEmpty) return;

    // Chart boundary definitions
    const double leftPadding = 30.0;
    const double bottomPadding = 25.0;
    final double chartWidth = size.width - leftPadding;
    final double chartHeight = size.height - bottomPadding;

    final double maxV = data.isEmpty || data.every((e) => e == 0)
        ? 5.0
        : data.reduce(max).clamp(1.0, double.infinity);

    // 1. Draw Y-Axis Text
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    final yLabels = [
      maxV.toInt().toString(),
      (maxV / 2).toInt().toString(),
      '0',
    ];
    for (int i = 0; i < yLabels.length; i++) {
      textPainter.text = TextSpan(
        text: yLabels[i],
        style: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      final yPos = (i * (chartHeight / 2)) - (textPainter.height / 2);
      textPainter.paint(canvas, Offset(0, yPos));
    }

    // Generate Points for the curve
    final int pointCount = min(data.length, labels.length);
    final points = List.generate(pointCount, (i) {
      final x = leftPadding + (i * chartWidth / (pointCount - 1));
      final y = chartHeight - ((data[i] / maxV) * chartHeight);
      return Offset(x, y);
    });

    if (points.isEmpty) return;

    // 2. Draw Gradient Fill
    final fillPath = Path()..moveTo(points.first.dx, chartHeight);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i].dy);
      final cp2 = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        points[i + 1].dy,
      );
      fillPath.cubicTo(
        cp1.dx,
        cp1.dy,
        cp2.dx,
        cp2.dy,
        points[i + 1].dx,
        points[i + 1].dy,
      );
    }
    fillPath.lineTo(points.last.dx, chartHeight);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lineColor.withOpacity(0.3), lineColor.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight)),
    );

    // 3. Draw Smooth Line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final cp1 = Offset((points[i].dx + points[i + 1].dx) / 2, points[i].dy);
      final cp2 = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        points[i + 1].dy,
      );
      linePath.cubicTo(
        cp1.dx,
        cp1.dy,
        cp2.dx,
        cp2.dy,
        points[i + 1].dx,
        points[i + 1].dy,
      );
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round,
    );

    // 4. Draw X-Axis Labels and the Active Dot
    for (int i = 0; i < points.length; i++) {
      final isSelected = i == selectedIndex;

      // X-Axis Text
      textPainter.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          color: isSelected ? AppColors.textDark : Colors.grey.shade400,
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(points[i].dx - textPainter.width / 2, chartHeight + 10),
      );

      // Active Dot with Tooltip
      if (isSelected && data[i] > 0) {
        // Dot
        canvas.drawCircle(points[i], 6, Paint()..color = Colors.white);
        canvas.drawCircle(points[i], 4, Paint()..color = lineColor);

        // Tooltip bubble
        final valueText = data[i].toInt().toString();
        textPainter.text = TextSpan(
          text: valueText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();

        final bubbleRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(points[i].dx, points[i].dy - 22),
            width: textPainter.width + 16,
            height: 20,
          ),
          const Radius.circular(6),
        );
        canvas.drawRRect(bubbleRect, Paint()..color = lineColor);
        textPainter.paint(
          canvas,
          Offset(points[i].dx - textPainter.width / 2, points[i].dy - 29),
        );
      }
    }
  }

  @override
  bool shouldRepaint(CurvedChartPainter old) => true;
}
