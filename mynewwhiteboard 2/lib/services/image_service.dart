import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/stroke.dart';

class ImageService {
  static Future<String?> exportAsImage(
    List<Stroke> strokes,
    Size size,
    double scale,
    Offset offset,
  ) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Apply the same transform as the whiteboard
      canvas.translate(offset.dx, offset.dy);
      canvas.scale(scale);

      // Draw white background
      final paint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRect(Offset.zero & size, paint);

      // Draw all strokes
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      for (final stroke in strokes) {
        strokePaint
          ..color = stroke.color
          ..strokeWidth = stroke.strokeWidth;
        _drawStroke(canvas, strokePaint, stroke.points);
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // TODO: Implement saving or sharing the image as needed.
      // For now, just return null or a placeholder.
      return null;
    } catch (e) {
      print('Error exporting image: $e');
    }
    return null;
  }

  static void _drawStroke(Canvas canvas, Paint paint, List<Offset> points) {
    if (points.length < 2) return;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);
  }
} 