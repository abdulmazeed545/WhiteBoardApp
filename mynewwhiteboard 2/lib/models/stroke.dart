/// A model class that represents a freehand stroke on the whiteboard.
/// This includes the points that make up the stroke, its color, width, and eraser state.

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

class Stroke {
  /// Unique identifier for the stroke
  final String id;
  
  /// List of points that make up the stroke path
  final List<Offset> points;
  
  /// Color of the stroke
  final Color color;
  
  /// Width of the stroke
  final double strokeWidth;
  
  /// Whether this stroke is an eraser stroke
  final bool isEraser;

  /// List of control points for smooth curve calculation
  final List<Offset> controlPoints;

  /// Creates a new stroke with the specified properties.
  /// If no ID is provided, a new UUID is generated.
  Stroke({
    String? id,
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
    List<Offset>? controlPoints,
  }) : id = id ?? const Uuid().v4(),
      controlPoints = controlPoints ?? [];

  /// Creates a copy of this stroke with the specified properties changed.
  /// Used for updating stroke properties without creating a new instance.
  Stroke copyWith({
    List<Offset>? points,
    Color? color,
    double? strokeWidth,
    bool? isEraser,
    List<Offset>? controlPoints,
  }) {
    return Stroke(
      id: id,
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isEraser: isEraser ?? this.isEraser,
      controlPoints: controlPoints ?? this.controlPoints,
    );
  }

  /// Converts the stroke to a JSON map for serialization.
  /// Used for saving the whiteboard state.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'points': points.map((point) => {'x': point.dx, 'y': point.dy}).toList(),
      'color': color.value,
      'strokeWidth': strokeWidth,
      'isEraser': isEraser,
      'controlPoints': controlPoints.map((point) => {'x': point.dx, 'y': point.dy}).toList(),
    };
  }

  /// Creates a Stroke from a JSON map.
  /// Used for loading the whiteboard state.
  factory Stroke.fromJson(Map<String, dynamic> json) {
    return Stroke(
      id: json['id'],
      points: (json['points'] as List)
          .map((point) => Offset(point['x'], point['y']))
          .toList(),
      color: Color(json['color']),
      strokeWidth: json['strokeWidth'],
      isEraser: json['isEraser'],
      controlPoints: (json['controlPoints'] as List)
          .map((point) => Offset(point['x'], point['y']))
          .toList(),
    );
  }

  /// Creates a smooth curve through the points using cubic Bezier curves
  Path createSmoothPath() {
    if (points.length < 2) return Path();

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    if (points.length == 2) {
      path.lineTo(points[1].dx, points[1].dy);
      return path;
    }

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i == 0 ? points[0] : points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i == points.length - 2 ? points[points.length - 1] : points[i + 2];

      // Calculate control points for smooth curve
      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
      );
      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
      );

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    return path;
  }
} 