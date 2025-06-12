/// A model class that represents a drawing element on the whiteboard.
/// This includes shapes, text, and their properties.

import 'package:flutter/material.dart';
import 'shape_type.dart';

/// A class that represents any drawable element on the whiteboard.
/// This includes shapes, text, and their associated properties.
class DrawingElement {
  // Basic properties
  final String id;           // Unique identifier for the element
  final Offset startPoint;   // Starting point of the element
  final Offset endPoint;     // Ending point of the element
  final Color color;         // Color of the element
  final double strokeWidth;  // Width of the stroke
  
  // Image properties
  final String? imageData;    // Base64 encoded image data
  final double? imageWidth;   // Width of the image
  final double? imageHeight;  // Height of the image
  
  // Shape properties
  final ShapeType? shapeType;  // Type of shape (if it's a shape)
  final bool isDashed;         // Whether the stroke is dashed
  final bool isHighlight;      // Whether the element is in highlight mode
  final BlendMode blendMode;   // Blend mode for highlight effects
  
  // Text properties
  final String? text;           // Text content (if it's a text element)
  final double? fontSize;       // Font size for text
  final String? fontFamily;     // Font family for text
  final TextAlignment? textAlignment;  // Text alignment
  
  // Selection properties
  final bool isSelected;        // Whether the element is selected
  final Map<String, Offset>? resizeHandles; // Changed from single resizeHandle to map of handles
  final Offset? deleteHandle;   // Position of the delete handle

  /// Creates a new drawing element with the specified properties.
  DrawingElement({
    required this.id,
    required this.startPoint,
    required this.endPoint,
    required this.color,
    required this.strokeWidth,
    this.shapeType,
    this.isDashed = false,
    this.isHighlight = false,
    this.blendMode = BlendMode.srcOver,
    this.text,
    this.fontSize,
    this.fontFamily,
    this.textAlignment,
    this.isSelected = false,
    this.resizeHandles,
    this.deleteHandle,
    this.imageData,
    this.imageWidth,
    this.imageHeight,
  });

  /// Gets the bounding rectangle of the element.
  /// For text elements, calculates bounds based on text length and font size.
  /// For shapes, uses the start and end points.
  Rect get bounds {
    if (imageData != null) {
      // For images, use the image dimensions
      return Rect.fromLTWH(
        startPoint.dx,
        startPoint.dy,
        imageWidth ?? 200,  // Default width if not specified
        imageHeight ?? 200, // Default height if not specified
      );
    } else if (text != null) {
      // For text elements, use a fixed width based on text length
      final width = (text?.length ?? 0) * (fontSize ?? 16) * 0.6;
      final height = (fontSize ?? 16) * 1.5;
      return Rect.fromLTWH(
        startPoint.dx,
        startPoint.dy,
        width,
        height,
      );
    }
    return Rect.fromPoints(startPoint, endPoint);
  }

  /// Checks if a point is within the element's bounds.
  /// For text elements, uses the text bounds.
  /// For shapes, uses the shape's bounding rectangle.
  bool contains(Offset point) {
    if (text != null) {
      return bounds.contains(point);
    }
    final rect = bounds;
    return rect.contains(point);
  }

  /// Checks if a point is near any resize handle.
  bool isNearResizeHandle(Offset point, double threshold) {
    if (resizeHandles == null) return false;
    return resizeHandles!.values.any((handle) => 
      (point - handle).distance < threshold
    );
  }

  /// Gets the nearest resize handle to the given point.
  String? getNearestResizeHandle(Offset point, double threshold) {
    if (resizeHandles == null) return null;
    
    String? nearestHandle;
    double minDistance = threshold;
    
    resizeHandles!.forEach((key, handle) {
      final distance = (point - handle).distance;
      if (distance < minDistance) {
        minDistance = distance;
        nearestHandle = key;
      }
    });
    
    return nearestHandle;
  }

  /// Checks if a point is near the delete handle.
  /// Returns true if the point is within the specified threshold distance.
  bool isNearDeleteHandle(Offset point, double threshold) {
    if (deleteHandle == null) return false;
    final dx = point.dx - deleteHandle!.dx;
    final dy = point.dy - deleteHandle!.dy;
    // Use a smaller threshold for more precise touch detection
    return (dx * dx + dy * dy) <= threshold * threshold;
  }

  /// Creates a copy of this element with the specified properties changed.
  /// Used for updating element properties without creating a new instance.
  DrawingElement copyWith({
    String? id,
    Offset? startPoint,
    Offset? endPoint,
    Color? color,
    double? strokeWidth,
    ShapeType? shapeType,
    bool? isDashed,
    bool? isHighlight,
    BlendMode? blendMode,
    String? text,
    double? fontSize,
    String? fontFamily,
    TextAlignment? textAlignment,
    bool? isSelected,
    Map<String, Offset>? resizeHandles,
    Offset? deleteHandle,
    String? imageData,
    double? imageWidth,
    double? imageHeight,
  }) {
    return DrawingElement(
      id: id ?? this.id,
      startPoint: startPoint ?? this.startPoint,
      endPoint: endPoint ?? this.endPoint,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      shapeType: shapeType ?? this.shapeType,
      isDashed: isDashed ?? this.isDashed,
      isHighlight: isHighlight ?? this.isHighlight,
      blendMode: blendMode ?? this.blendMode,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      textAlignment: textAlignment ?? this.textAlignment,
      isSelected: isSelected ?? this.isSelected,
      resizeHandles: resizeHandles ?? this.resizeHandles,
      deleteHandle: deleteHandle ?? this.deleteHandle,
      imageData: imageData ?? this.imageData,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
    );
  }

  /// Converts the element to a JSON map for serialization.
  /// Used for saving the whiteboard state.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startPoint': {'dx': startPoint.dx, 'dy': startPoint.dy},
      'endPoint': {'dx': endPoint.dx, 'dy': endPoint.dy},
      'color': color.value,
      'strokeWidth': strokeWidth,
      'isDashed': isDashed,
      'shapeType': shapeType?.index,
      'text': text,
      'fontSize': fontSize,
      'fontFamily': fontFamily,
      'textAlignment': textAlignment?.index,
      'isHighlight': isHighlight,
      'blendMode': blendMode.index,
      'isSelected': isSelected,
      'imageData': imageData,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
    };
  }

  /// Creates a DrawingElement from a JSON map.
  /// Used for loading the whiteboard state.
  factory DrawingElement.fromJson(Map<String, dynamic> json) {
    return DrawingElement(
      id: json['id'],
      startPoint: Offset(
        (json['startPoint']['dx'] as num).toDouble(),
        (json['startPoint']['dy'] as num).toDouble(),
      ),
      endPoint: Offset(
        (json['endPoint']['dx'] as num).toDouble(),
        (json['endPoint']['dy'] as num).toDouble(),
      ),
      color: Color(json['color']),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
      shapeType: json['shapeType'] != null ? ShapeType.values[json['shapeType']] : null,
      isDashed: json['isDashed'] ?? false,
      isHighlight: json['isHighlight'] ?? false,
      blendMode: json['blendMode'] != null ? BlendMode.values[json['blendMode']] : BlendMode.srcOver,
      text: json['text'],
      fontSize: json['fontSize'] != null ? (json['fontSize'] as num).toDouble() : null,
      fontFamily: json['fontFamily'],
      textAlignment: json['textAlignment'] != null ? TextAlignment.values[json['textAlignment']] : null,
      isSelected: json['isSelected'] ?? false,
      imageData: json['imageData'],
      imageWidth: json['imageWidth'] != null ? (json['imageWidth'] as num).toDouble() : null,
      imageHeight: json['imageHeight'] != null ? (json['imageHeight'] as num).toDouble() : null,
    );
  }
} 