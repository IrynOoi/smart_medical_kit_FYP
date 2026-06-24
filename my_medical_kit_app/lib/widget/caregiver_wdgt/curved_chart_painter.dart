// curved_chart_painter.dart - A custom painter for drawing a smooth curved line chart
// with gradient fill, X/Y axis labels, and a highlighted point with a tooltip.
// Used to display adherence data (e.g., taken/missed doses over time).

import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:my_medical_kit_app/theme/colors.dart';

// ----------------------------------------------------------------------
// CurvedChartPainter – a CustomPainter that draws a single‑line chart with:
//   - Y‑axis labels (max, half, zero)
//   - X‑axis labels (provided as a list of strings)
//   - A smoothed cubic Bézier curve connecting data points
//   - A translucent gradient fill under the curve
//   - A highlighted dot and tooltip bubble at the selected index
// ----------------------------------------------------------------------
class CurvedChartPainter extends CustomPainter {
  // List of numeric values to plot (e.g., adherence counts per day)
  final List<double> data;
  // Corresponding X‑axis labels (e.g., days of the week or hours)
  final List<String> labels;
  // Primary colour of the line and tooltip
  final Color lineColor;
  // Index of the data point that should be highlighted (e.g., the current day)
  final int selectedIndex;

  CurvedChartPainter({
    required this.data,
    required this.labels,
    required this.lineColor,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Exit early if there's no data to draw
    if (data.isEmpty || labels.isEmpty) return;

    // ------------------------------------------------------------------
    // 1. Define chart boundaries (padding from the canvas edges)
    // ------------------------------------------------------------------
    const double leftPadding = 30.0; // space for Y‑axis labels
    const double bottomPadding = 25.0; // space for X‑axis labels
    const double topPadding = 35.0; // space for tooltips
    final double chartWidth = size.width - leftPadding;
    final double chartHeight = size.height - bottomPadding - topPadding;
    final double graphBottom = topPadding + chartHeight;

    // Calculate the maximum value in the data. Make it an even integer
    // so the Y-axis labels align perfectly with the graph points.
    double rawMax = data.isEmpty ? 0 : data.reduce(max);
    int topValue = rawMax < 2 ? 2 : rawMax.ceil();
    if (topValue % 2 != 0) {
      topValue += 1; // Make it even so the half-value is an integer
    }
    final double maxV = topValue.toDouble();

    // ------------------------------------------------------------------
    // 2. Draw Y‑axis labels (max, half, zero) on the left side
    // ------------------------------------------------------------------
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    final yLabels = [
      maxV.toInt().toString(), // top value
      (maxV / 2).toInt().toString(), // middle value
      '0', // bottom value
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
      // Position the label vertically – evenly spaced across the chart height
      final yPos = topPadding + (i * (chartHeight / 2)) - (textPainter.height / 2);
      textPainter.paint(canvas, Offset(0, yPos));
    }

    // ------------------------------------------------------------------
    // 3. Convert data points to screen coordinates (Offset)
    // ------------------------------------------------------------------
    final int pointCount = min(data.length, labels.length);
    final points = List.generate(pointCount, (i) {
      final x = leftPadding + (i * chartWidth / (pointCount - 1));
      final y = graphBottom - ((data[i] / maxV) * chartHeight);
      return Offset(x, y);
    });

    if (points.isEmpty) return;

    // ------------------------------------------------------------------
    // 4. Draw the gradient fill under the curve
    // ------------------------------------------------------------------
    final fillPath = Path()
      ..moveTo(points.first.dx, graphBottom); // start from bottom‑left

    // Build a smooth cubic Bézier path through the points
    for (int i = 0; i < points.length - 1; i++) {
      // Control points: the x‑midpoint between the current and next point,
      // and the y‑values of the current and next point respectively.
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
    // Close the path by going to the bottom‑right and back to the start
    fillPath.lineTo(points.last.dx, graphBottom);
    fillPath.close();

    // Paint the fill with a vertical gradient (line colour fading to transparent)
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.3), // visible at the top
            lineColor.withValues(alpha: 0.0), // fully transparent at the bottom
          ],
        ).createShader(Rect.fromLTWH(0, topPadding, size.width, chartHeight)),
    );

    // ------------------------------------------------------------------
    // 5. Draw the smooth line over the fill
    // ------------------------------------------------------------------
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

    // ------------------------------------------------------------------
    // 6. Draw X‑axis labels and the highlighted point (dot + tooltip)
    // ------------------------------------------------------------------
    for (int i = 0; i < points.length; i++) {
      final isSelected = i == selectedIndex;

      // 6a. X‑axis label (below the chart)
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
        Offset(points[i].dx - textPainter.width / 2, graphBottom + 10),
      );

      // 6b. If this is the selected point and its value > 0, draw a dot + tooltip
      if (isSelected && data[i] > 0) {
        // White outer ring + inner coloured dot
        canvas.drawCircle(points[i], 6, Paint()..color = Colors.white);
        canvas.drawCircle(points[i], 4, Paint()..color = lineColor);

        // Tooltip bubble showing the value
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
        // Draw the tooltip background (same colour as the line)
        canvas.drawRRect(bubbleRect, Paint()..color = lineColor);
        // Draw the text centered inside the bubble
        textPainter.paint(
          canvas,
          Offset(points[i].dx - textPainter.width / 2, points[i].dy - 29),
        );
      }
    }
  }

  // Always repaint when the painter is rebuilt (simplistic; could be optimised)
  @override
  bool shouldRepaint(CurvedChartPainter old) => true;
}
