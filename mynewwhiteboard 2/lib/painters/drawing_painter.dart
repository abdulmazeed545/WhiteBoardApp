/// A custom painter that handles rendering all drawing elements on the whiteboard.
/// This includes shapes, text, strokes, and selection handles.

import 'package:flutter/material.dart';
import 'dart:math';
import '../models/drawing_element.dart';
import '../models/stroke.dart';
import '../models/shape_type.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

class DrawingPainter extends CustomPainter {
  /// List of all drawing elements (shapes and text) on the whiteboard
  final List<DrawingElement> elements;
  
  /// The element currently being drawn
  final DrawingElement? currentElement;
  
  /// List of all freehand strokes on the whiteboard
  final List<Stroke> strokes;
  
  /// The stroke currently being drawn
  final Stroke? currentStroke;
  
  /// The currently selected element (if any)
  final DrawingElement? selectedElement;

  // Static cache for decoded images
  static final Map<String, ui.Image> _imageCache = {};

  final void Function()? onImageDecoded;

  DrawingPainter({
    required this.elements,
    this.currentElement,
    required this.strokes,
    this.currentStroke,
    this.selectedElement,
    this.onImageDecoded,
  });

  @override
  void paint(Canvas canvas, Size size) {
    print('DrawingPainter.paint called. Painting ${strokes.length} strokes.');
    
    // Draw all strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // Draw all elements
    for (final element in elements) {
      if (element.imageData != null) {
        _drawImageSync(canvas, element);
      } else if (element.text != null) {
        _drawText(canvas, element);
      } else if (element.shapeType != null) {
        _drawShape(canvas, element);
      }
    }

    // Draw current stroke if any
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }

    // Draw current element if any
    if (currentElement != null) {
      if (currentElement!.text != null) {
        _drawText(canvas, currentElement!);
      } else if (currentElement!.shapeType != null) {
        _drawShape(canvas, currentElement!);
      }
    }

    // Draw selection handles for selected element
    if (selectedElement != null) {
      _drawSelectionHandles(canvas, selectedElement!);
    }
  }

  /// Draws a freehand stroke on the canvas.
  /// Creates a smooth path from the stroke points and renders it with the specified style.
  void _drawStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.length < 2) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Use the smooth path for drawing
    final path = stroke.createSmoothPath();
    canvas.drawPath(path, paint);
  }

  /// Draws a drawing element (shape or text) on the canvas.
  /// Handles different types of elements and their selection states.
  void _drawElement(Canvas canvas, DrawingElement element) {
    final paint = Paint()
      ..color = element.color
      ..strokeWidth = element.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (element.isDashed) {
      paint.shader = null;
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 0);
    }

    if (element.isHighlight) {
      paint.blendMode = element.blendMode;
    }

    if (element.text != null) {
      // Draw text element
      final textStyle = TextStyle(
        color: element.color,
        fontSize: element.fontSize ?? 16,
        fontFamily: element.fontFamily,
      );
      final textSpan = TextSpan(
        text: element.text,
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: _getTextAlign(element.textAlignment),
      );
      textPainter.layout();
      textPainter.paint(canvas, element.startPoint);

      // Draw selection UI if text is selected
      if (element.isSelected) {
        _drawSelectionUI(canvas, element);
      }
      return;
    }

    // Draw shape element
    if (element.isDashed) {
      _drawDashedLine(canvas, element.startPoint, element.endPoint, paint);
    } else {
      switch (element.shapeType) {
        case ShapeType.line:
          canvas.drawLine(element.startPoint, element.endPoint, paint);
          break;
        case ShapeType.rectangle:
          canvas.drawRect(element.bounds, paint);
          break;
        case ShapeType.ellipse:
          canvas.drawOval(element.bounds, paint);
          break;
        case ShapeType.triangle:
          _drawTriangle(canvas, element, paint);
          break;
        case ShapeType.arrow:
          _drawArrow(canvas, element, paint);
          break;
        case ShapeType.doubleArrow:
          _drawDoubleArrow(canvas, element, paint);
          break;
        case ShapeType.text:
          // Text is handled separately
          break;
        default:
          break;
      }
    }

    // Draw selection UI if shape is selected
    if (element.isSelected) {
      _drawSelectionUI(canvas, element);
    }
  }

  /// Draws selection UI for a selected element.
  /// This includes the selection border, resize handle, and delete handle.
  void _drawSelectionUI(Canvas canvas, DrawingElement element) {
    // Draw selection border
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(element.bounds, borderPaint);

    // Draw resize handles
    if (element.resizeHandles != null) {
      final handlePaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;
      
      element.resizeHandles!.forEach((key, handle) {
        canvas.drawCircle(handle, 6, handlePaint);
      });
    }

    // Draw delete handle
    if (element.deleteHandle != null) {
      // Draw larger delete handle circle with a white border
      final deleteCirclePaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;
      final deleteBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      // Draw the main circle
      canvas.drawCircle(
        element.deleteHandle!,
        12,
        deleteCirclePaint,
      );
      // Draw the white border
      canvas.drawCircle(
        element.deleteHandle!,
        12,
        deleteBorderPaint,
      );

      // Draw larger X in delete handle
      final xPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      // Draw the X with a slight offset to make it more visible
      final xOffset = 5.0;
      canvas.drawLine(
        Offset(element.deleteHandle!.dx - xOffset, element.deleteHandle!.dy - xOffset),
        Offset(element.deleteHandle!.dx + xOffset, element.deleteHandle!.dy + xOffset),
        xPaint,
      );
      canvas.drawLine(
        Offset(element.deleteHandle!.dx + xOffset, element.deleteHandle!.dy - xOffset),
        Offset(element.deleteHandle!.dx - xOffset, element.deleteHandle!.dy + xOffset),
        xPaint,
      );
    }
  }

  /// Draws an arrow shape on the canvas.
  /// Creates a line with an arrowhead at the end point.
  void _drawArrow(Canvas canvas, DrawingElement element, Paint paint) {
    final path = Path();
    final rect = element.bounds;
    final arrowSize = element.strokeWidth * 2;
    
    // Draw the line
    path.moveTo(rect.left, rect.top + rect.height / 2);
    path.lineTo(rect.right - arrowSize, rect.top + rect.height / 2);
    
    // Draw the arrow head
    path.moveTo(rect.right, rect.top + rect.height / 2);
    path.lineTo(rect.right - arrowSize, rect.top);
    path.lineTo(rect.right - arrowSize, rect.bottom);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  /// Draws a double-headed arrow shape on the canvas.
  /// Creates a line with arrowheads at both ends.
  void _drawDoubleArrow(Canvas canvas, DrawingElement element, Paint paint) {
    final path = Path();
    final rect = element.bounds;
    final arrowSize = element.strokeWidth * 2;
    
    // Draw the line
    path.moveTo(rect.left + arrowSize, rect.top + rect.height / 2);
    path.lineTo(rect.right - arrowSize, rect.top + rect.height / 2);
    
    // Draw the right arrow head
    path.moveTo(rect.right, rect.top + rect.height / 2);
    path.lineTo(rect.right - arrowSize, rect.top);
    path.lineTo(rect.right - arrowSize, rect.bottom);
    path.close();
    
    // Draw the left arrow head
    path.moveTo(rect.left, rect.top + rect.height / 2);
    path.lineTo(rect.left + arrowSize, rect.top);
    path.lineTo(rect.left + arrowSize, rect.bottom);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  /// Draws a triangle shape on the canvas.
  /// Creates an equilateral triangle between the start and end points.
  void _drawTriangle(Canvas canvas, DrawingElement element, Paint paint) {
    final path = Path();
    final rect = element.bounds;
    
    path.moveTo(rect.left + rect.width / 2, rect.top);
    path.lineTo(rect.right, rect.bottom);
    path.lineTo(rect.left, rect.bottom);
    path.close();
    
    canvas.drawPath(path, paint);
  }

  /// Draws a dashed line on the canvas.
  /// Creates a line with evenly spaced dashes.
  void _drawDashedLine(Canvas canvas, Offset startPoint, Offset endPoint, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 5.0;

    final dx = endPoint.dx - startPoint.dx;
    final dy = endPoint.dy - startPoint.dy;
    final distance = sqrt(dx * dx + dy * dy);
    final angle = atan2(dy, dx);

    var currentDistance = 0.0;
    while (currentDistance < distance) {
      final start = Offset(
        startPoint.dx + currentDistance * cos(angle),
        startPoint.dy + currentDistance * sin(angle),
      );
      final end = Offset(
        startPoint.dx + (currentDistance + dashWidth) * cos(angle),
        startPoint.dy + (currentDistance + dashWidth) * sin(angle),
      );
      canvas.drawLine(start, end, paint);
      currentDistance += dashWidth + dashSpace;
    }
  }

  /// Converts the TextAlignment enum to Flutter's TextAlign.
  TextAlign _getTextAlign(TextAlignment? alignment) {
    switch (alignment) {
      case TextAlignment.left:
        return TextAlign.left;
      case TextAlignment.center:
        return TextAlign.center;
      case TextAlignment.right:
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }

  void _drawSelectionHandles(Canvas canvas, DrawingElement element) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw selection rectangle
    canvas.drawRect(element.bounds, paint);

    // Draw resize handles
    if (element.resizeHandles != null) {
      final handlePaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.fill;
      element.resizeHandles!.forEach((key, handle) {
        canvas.drawCircle(handle, 6, handlePaint);
      });
    }

    // Draw delete handle
    if (element.deleteHandle != null) {
      final deletePaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;
      canvas.drawCircle(element.deleteHandle!, 6, deletePaint);
    }
  }

  /// Draws an image element on the canvas using a cache for decoded images.
  void _drawImageSync(Canvas canvas, DrawingElement element) {
    if (element.imageData == null) return;
    final String cacheKey = element.id + (element.imageData?.substring(0, 20) ?? '');
    final rect = element.bounds;
    final cachedImage = _imageCache[cacheKey];
    if (cachedImage != null) {
      // Draw the cached image
      canvas.drawImageRect(
        cachedImage,
        Rect.fromLTWH(0, 0, cachedImage.width.toDouble(), cachedImage.height.toDouble()),
        rect,
        Paint(),
      );
      if (element.isSelected) {
        _drawSelectionUI(canvas, element);
      }
      return;
    }
    // If not cached, decode in the background and trigger repaint
    _decodeAndCacheImage(element, cacheKey);
    // Optionally, draw a placeholder (e.g., a gray box)
    final paint = Paint()..color = Colors.grey.shade300;
    canvas.drawRect(rect, paint);
    if (element.isSelected) {
      _drawSelectionUI(canvas, element);
    }
  }

  void _decodeAndCacheImage(DrawingElement element, String cacheKey) async {
    try {
      final bytes = base64Decode(element.imageData!);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      _imageCache[cacheKey] = image;
      if (onImageDecoded != null) {
        onImageDecoded!();
      }
    } catch (e) {
      print('Error decoding image: $e');
    }
  }

  void _drawText(Canvas canvas, DrawingElement element) {
    final textStyle = TextStyle(
      color: element.color,
      fontSize: element.fontSize ?? 16,
      fontFamily: element.fontFamily,
    );
    final textSpan = TextSpan(
      text: element.text,
      style: textStyle,
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: _getTextAlign(element.textAlignment),
    );
    textPainter.layout();
    textPainter.paint(canvas, element.startPoint);

    // Draw selection UI if text is selected
    if (element.isSelected) {
      _drawSelectionUI(canvas, element);
    }
  }

  void _drawShape(Canvas canvas, DrawingElement element) {
    final paint = Paint()
      ..color = element.color
      ..strokeWidth = element.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (element.isDashed) {
      paint.shader = null;
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 0);
    }

    if (element.isHighlight) {
      paint.blendMode = element.blendMode;
    }

    switch (element.shapeType) {
      case ShapeType.line:
        canvas.drawLine(element.startPoint, element.endPoint, paint);
        break;
      case ShapeType.rectangle:
        canvas.drawRect(element.bounds, paint);
        break;
      case ShapeType.ellipse:
        canvas.drawOval(element.bounds, paint);
        break;
      case ShapeType.triangle:
        _drawTriangle(canvas, element, paint);
        break;
      case ShapeType.arrow:
        _drawArrow(canvas, element, paint);
        break;
      case ShapeType.doubleArrow:
        _drawDoubleArrow(canvas, element, paint);
        break;
      default:
        break;
    }

    // Draw selection UI if shape is selected
    if (element.isSelected) {
      _drawSelectionUI(canvas, element);
    }
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return elements != oldDelegate.elements ||
        currentElement != oldDelegate.currentElement ||
        strokes != oldDelegate.strokes ||
        currentStroke != oldDelegate.currentStroke ||
        selectedElement != oldDelegate.selectedElement;
  }
} 