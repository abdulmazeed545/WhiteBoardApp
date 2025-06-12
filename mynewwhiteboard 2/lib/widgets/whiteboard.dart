/// A Flutter whiteboard widget that provides drawing, text, and shape functionality.
/// This widget handles all drawing operations, including freehand drawing, shapes,
/// text input, and element manipulation.

import 'package:flutter/material.dart';
import 'dart:math';
import '../models/stroke.dart';
import '../models/drawing_element.dart' as de;
import '../painters/drawing_painter.dart';
import 'toolbar.dart';
import '../models/shape_type.dart';
import '../services/socket_service.dart';
import '../screens/room_entry_screen.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

/// The main whiteboard widget that manages the drawing canvas and all drawing operations.
class Whiteboard extends StatefulWidget {
  final List<Stroke> strokes;
  final List<de.DrawingElement> elements;
  final void Function(Stroke)? onStrokeDrawn;
  final bool isTeacher;
  final VoidCallback? onImageSelected;
  const Whiteboard({super.key, required this.strokes, required this.elements, this.onStrokeDrawn, required this.isTeacher, this.onImageSelected});

  @override
  State<Whiteboard> createState() => WhiteboardState();
}

/// The state class for the Whiteboard widget that manages all drawing operations
/// and maintains the state of the canvas.
class WhiteboardState extends State<Whiteboard> {
  // No longer store _elements internally; use widget.elements
  final List<Stroke> _redoStrokes = []; // Undo/redo stack for strokes
  final List<de.DrawingElement> _redoElements = []; // Undo/redo stack for elements
  
  // Current drawing state
  Stroke? _currentStroke; // Current stroke being drawn
  de.DrawingElement? _currentElement; // Current element being drawn
  Color _currentColor = Colors.black; // Current drawing color
  double _currentStrokeWidth = 2.0; // Current stroke width
  bool _isEraser = false; // Eraser mode flag
  bool _isDashed = false; // Dashed line mode flag
  bool _isHighlight = false; // Highlight mode flag
  Offset? _currentPosition; // Current cursor position
  
  // Shape and text properties
  ShapeType? _currentShapeType; // Current shape type being drawn
  String? _currentText; // Current text being added
  double _currentFontSize = 16.0; // Current font size
  String _currentFontFamily = 'Arial'; // Current font family
  TextAlignment _currentTextAlignment = TextAlignment.left; // Current text alignment
  BlendMode _currentBlendMode = BlendMode.srcOver; // Current blend mode for highlights
  
  // Selection and resizing state
  de.DrawingElement? _selectedElement; // Currently selected element
  bool _isResizing = false; // Resizing mode flag
  Offset? _resizeStartPoint; // Starting point for resizing
  String? _activeResizeHandle; // Currently active resize handle
  bool _isNearDeleteHandle = false; // Flag for delete handle proximity
  bool _isDragging = false; // Flag for dragging mode
  Offset? _dragStartPoint; // Starting point for dragging
  Offset? _dragOffset; // Current drag offset
  
  // Zoom and pan state
  double _scale = 1.0; // Current zoom level
  Offset _offset = Offset.zero; // Current pan offset
  double? _previousScale; // Previous zoom level for smooth transitions

  // Modify debouncing variables
  DateTime? _lastEmitTime;
  static const int _emitDebounceMs = 16; // ~60fps
  Stroke? _lastEmittedStroke;
  bool _isDrawing = false;

  @override
  void initState() {
    super.initState();
    print('WhiteboardState created: $this');
  }

  @override
  void dispose() {
    print('WhiteboardState disposed: $this');
    super.dispose();
  }

  /// Handles the start of a drawing operation at the given position.
  /// This method determines what type of drawing operation to perform based on
  /// the current tool selection and state.
  void _startDrawing(Offset position) {
    setState(() {
      _currentPosition = position;
    });
    
    if (_isEraser) {
      _eraseStrokes(position);
    } else if (_currentText != null) {
      _addText(position);
    } else if (_currentShapeType != null) {
      _startShape(position);
    } else {
      // Check for element selection
      de.DrawingElement? foundElement;
      for (final element in widget.elements.reversed) {
        if (element.contains(position)) {
          foundElement = element;
          break;
        }
      }
      
      if (foundElement != null) {
        setState(() {
          _selectedElement = foundElement;
          // Update selection handles
          final index = widget.elements.indexOf(_selectedElement!);
          if (index != -1) {
            final bounds = _selectedElement!.bounds;
            final handles = {
              'topLeft': Offset(bounds.left, bounds.top),
              'topCenter': Offset(bounds.center.dx, bounds.top),
              'topRight': Offset(bounds.right, bounds.top),
              'middleLeft': Offset(bounds.left, bounds.center.dy),
              'middleRight': Offset(bounds.right, bounds.center.dy),
              'bottomLeft': Offset(bounds.left, bounds.bottom),
              'bottomCenter': Offset(bounds.center.dx, bounds.bottom),
              'bottomRight': Offset(bounds.right, bounds.bottom),
            };
            widget.elements[index] = _selectedElement!.copyWith(
              isSelected: true,
              resizeHandles: handles,
              deleteHandle: Offset(bounds.right - 30, bounds.top + 30),
            );
            _selectedElement = widget.elements[index];
          }
        });
        
        // Handle resize, delete, and drag operations
        if (_selectedElement!.isNearResizeHandle(position, 20.0)) {
          _isResizing = true;
          _resizeStartPoint = position;
          _activeResizeHandle = _selectedElement!.getNearestResizeHandle(position, 20.0);
        }
        else if (_selectedElement!.isNearDeleteHandle(position, 20.0)) {
          _deleteSelectedElement();
        }
        else {
          // Start dragging
          _isDragging = true;
          _dragStartPoint = position;
          _dragOffset = Offset.zero;
        }
      } else {
        deselectElement();
        _startStroke(position);
      }
    }
  }

  /// Starts a new freehand stroke at the given position.
  /// This is used for freehand drawing and shape detection.
  void _startStroke(Offset position) {
    setState(() {
      _currentStroke = Stroke(
        points: [position],
        color: _currentColor,
        strokeWidth: _currentStrokeWidth,
        isEraser: _isEraser,
      );
      _isDrawing = true;
      _redoStrokes.clear();
      
      // Emit initial stroke
      if (widget.isTeacher) {
        _emitStrokeUpdate();
      }
    });
  }

  /// Starts drawing a new shape at the given position.
  /// This is used when a shape tool is selected.
  void _startShape(Offset position) {
    setState(() {
      _currentElement = de.DrawingElement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startPoint: position,
        endPoint: position,
        color: _currentColor,
        strokeWidth: _currentStrokeWidth,
        isDashed: _isDashed,
        shapeType: _currentShapeType,
        isHighlight: _isHighlight,
        blendMode: _isHighlight ? _currentBlendMode : BlendMode.srcOver,
      );
      _redoElements.clear();
    });
  }

  /// Adds text at the given position using the current text properties.
  /// This is used when text input is active.
  void _addText(Offset position) {
    if (_currentText == null) return;
    
    setState(() {
      final width = (_currentText!.length * _currentFontSize * 0.6);
      final height = (_currentFontSize * 1.5);
      final bounds = Rect.fromLTWH(position.dx, position.dy, width, height);
      final handles = {
        'topLeft': Offset(bounds.left, bounds.top),
        'topCenter': Offset(bounds.center.dx, bounds.top),
        'topRight': Offset(bounds.right, bounds.top),
        'middleLeft': Offset(bounds.left, bounds.center.dy),
        'middleRight': Offset(bounds.right, bounds.center.dy),
        'bottomLeft': Offset(bounds.left, bounds.bottom),
        'bottomCenter': Offset(bounds.center.dx, bounds.bottom),
        'bottomRight': Offset(bounds.right, bounds.bottom),
      };
      _currentElement = de.DrawingElement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startPoint: position,
        endPoint: position,
        color: _currentColor,
        strokeWidth: _currentStrokeWidth,
        text: _currentText,
        fontSize: _currentFontSize,
        fontFamily: _currentFontFamily,
        textAlignment: _currentTextAlignment,
        isSelected: true,
        resizeHandles: handles,
        deleteHandle: Offset(position.dx + width - 30, position.dy + 30),
      );
      widget.elements.add(_currentElement!);
      _selectedElement = _currentElement;
      _currentElement = null;
      _currentText = null;
    });
  }

  /// Updates the drawing state as the user moves the pointer.
  /// This handles continuous drawing, shape resizing, and erasing.
  void _draw(Offset position) {
    setState(() {
      _currentPosition = position;
    });

    if (_isEraser) {
      _eraseStrokes(position);
    } else if (_currentStroke != null) {
      _updateStroke(position);
    } else if (_currentElement != null) {
      _updateShape(position);
    } else if (_isResizing && _selectedElement != null && _resizeStartPoint != null) {
      _resizeElement(position);
    } else if (_isDragging && _selectedElement != null && _dragStartPoint != null) {
      _dragElement(position);
    }
  }

  /// Updates the current stroke with a new point.
  /// This is used for continuous freehand drawing.
  void _updateStroke(Offset position) {
    if (_currentStroke == null) return;

    // Create a new stroke with updated points to trigger rebuild
    final updatedStroke = Stroke(
      points: [..._currentStroke!.points, position],
      color: _currentStroke!.color,
      strokeWidth: _currentStroke!.strokeWidth,
      isEraser: _currentStroke!.isEraser,
    );

    setState(() {
      _currentStroke = updatedStroke;
      
      // Emit stroke updates with debouncing for socket
      if (widget.isTeacher && _isDrawing) {
        final now = DateTime.now();
        if (_lastEmitTime == null || 
            now.difference(_lastEmitTime!).inMilliseconds >= _emitDebounceMs) {
          _emitStrokeUpdate();
          _lastEmitTime = now;
        }
      }
    });
  }

  void _emitStrokeUpdate() {
    if (_currentStroke == null || !widget.isTeacher) return;

    final strokeData = {
      'type': 'stroke',
      'points': _currentStroke!.points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': _currentStroke!.color.value,
      'strokeWidth': _currentStroke!.strokeWidth,
      'isEraser': _currentStroke!.isEraser,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    SocketService().emitDraw(strokeData);
    _lastEmittedStroke = _currentStroke;
  }

  /// Updates the current shape with a new end point.
  /// This is used for continuous shape drawing and resizing.
  void _updateShape(Offset position) {
    setState(() {
      _currentElement = _currentElement!.copyWith(
        endPoint: position,
      );
    });
  }

  /// Erases strokes that intersect with the eraser at the given position.
  void _eraseStrokes(Offset position) {
    final eraserRadius = _currentStrokeWidth * 2;
    final eraserRadiusSquared = eraserRadius * eraserRadius;
    final socketService = SocketService();
    final strokesToRemove = <Stroke>[];

    setState(() {
      // Find strokes that intersect with the eraser
      final candidates = widget.strokes.where((stroke) {
        return stroke.points.any((point) => 
          Rect.fromCenter(
            center: position, 
            width: eraserRadius * 2, 
            height: eraserRadius * 2
          ).contains(point)
        );
      }).toList();

      // Check each candidate stroke for precise intersection
      for (final stroke in candidates) {
        bool shouldRemove = false;
        for (final point in stroke.points) {
          final dx = point.dx - position.dx;
          final dy = point.dy - position.dy;
          if ((dx * dx + dy * dy) <= eraserRadiusSquared) {
            shouldRemove = true;
            break;
          }
        }
        if (shouldRemove) {
          strokesToRemove.add(stroke);
        }
      }

      // Remove strokes and emit delete events
      for (final stroke in strokesToRemove) {
        widget.strokes.remove(stroke);
        if (widget.isTeacher) {
          // Emit delete_stroke event with stroke ID
          socketService.emitDeleteStroke(stroke.id);
        }
      }
    });
  }

  /// Resizes the selected element based on the new position.
  /// This is used for interactive resizing of shapes and text.
  void _resizeElement(Offset position) {
    if (_selectedElement == null || _resizeStartPoint == null || _activeResizeHandle == null) return;

    final dx = position.dx - _resizeStartPoint!.dx;
    final dy = position.dy - _resizeStartPoint!.dy;
    
    setState(() {
      final index = widget.elements.indexOf(_selectedElement!);
      if (index != -1) {
        final bounds = _selectedElement!.bounds;
        Offset newStartPoint = _selectedElement!.startPoint;
        Offset newEndPoint = _selectedElement!.endPoint;

        // Update points based on the active resize handle
        switch (_activeResizeHandle) {
          case 'topLeft':
            newStartPoint = Offset(bounds.left + dx, bounds.top + dy);
            break;
          case 'topCenter':
            newStartPoint = Offset(bounds.left, bounds.top + dy);
            break;
          case 'topRight':
            newStartPoint = Offset(bounds.left, bounds.top + dy);
            newEndPoint = Offset(bounds.right + dx, bounds.bottom);
            break;
          case 'middleLeft':
            newStartPoint = Offset(bounds.left + dx, bounds.top);
            break;
          case 'middleRight':
            newEndPoint = Offset(bounds.right + dx, bounds.bottom);
            break;
          case 'bottomLeft':
            newStartPoint = Offset(bounds.left + dx, bounds.top);
            newEndPoint = Offset(bounds.right, bounds.bottom + dy);
            break;
          case 'bottomCenter':
            newEndPoint = Offset(bounds.right, bounds.bottom + dy);
            break;
          case 'bottomRight':
            newEndPoint = Offset(bounds.right + dx, bounds.bottom + dy);
            break;
        }

        final newElement = _selectedElement!.copyWith(
          startPoint: newStartPoint,
          endPoint: newEndPoint,
        );
        widget.elements[index] = newElement;
        _selectedElement = newElement;
        _resizeStartPoint = position;

        // Update resize handles
        final newBounds = newElement.bounds;
        final handles = {
          'topLeft': Offset(newBounds.left, newBounds.top),
          'topCenter': Offset(newBounds.center.dx, newBounds.top),
          'topRight': Offset(newBounds.right, newBounds.top),
          'middleLeft': Offset(newBounds.left, newBounds.center.dy),
          'middleRight': Offset(newBounds.right, newBounds.center.dy),
          'bottomLeft': Offset(newBounds.left, newBounds.bottom),
          'bottomCenter': Offset(newBounds.center.dx, newBounds.bottom),
          'bottomRight': Offset(newBounds.right, newBounds.bottom),
        };
        widget.elements[index] = newElement.copyWith(resizeHandles: handles);
        _selectedElement = widget.elements[index];
        SocketService().emitMoveElement(widget.elements[index].toJson());
      }
    });
  }

  /// Drags the selected element based on the new position.
  void _dragElement(Offset position) {
    if (_selectedElement == null || _dragStartPoint == null) return;

    final dx = position.dx - _dragStartPoint!.dx;
    final dy = position.dy - _dragStartPoint!.dy;
    
    setState(() {
      final index = widget.elements.indexOf(_selectedElement!);
      if (index != -1) {
        final newElement = _selectedElement!.copyWith(
          startPoint: Offset(
            _selectedElement!.startPoint.dx + dx,
            _selectedElement!.startPoint.dy + dy,
          ),
          endPoint: Offset(
            _selectedElement!.endPoint.dx + dx,
            _selectedElement!.endPoint.dy + dy,
          ),
        );
        widget.elements[index] = newElement;
        _selectedElement = newElement;
        _dragStartPoint = position;

        // Update resize handles
        final bounds = newElement.bounds;
        final handles = {
          'topLeft': Offset(bounds.left, bounds.top),
          'topCenter': Offset(bounds.center.dx, bounds.top),
          'topRight': Offset(bounds.right, bounds.top),
          'middleLeft': Offset(bounds.left, bounds.center.dy),
          'middleRight': Offset(bounds.right, bounds.center.dy),
          'bottomLeft': Offset(bounds.left, bounds.bottom),
          'bottomCenter': Offset(bounds.center.dx, bounds.bottom),
          'bottomRight': Offset(bounds.right, bounds.bottom),
        };
        widget.elements[index] = newElement.copyWith(resizeHandles: handles);
        _selectedElement = widget.elements[index];
        SocketService().emitMoveElement(widget.elements[index].toJson());
      }
    });
  }

  /// Ends the current drawing operation.
  /// This finalizes the current stroke or shape and adds it to the canvas.
  void _endDrawing() {
    if (_currentStroke != null) {
      // Emit final stroke state
      if (widget.isTeacher) {
        _emitStrokeUpdate();
      }
      
      if (widget.onStrokeDrawn != null) {
        widget.onStrokeDrawn!(_currentStroke!);
      }
      
      setState(() {
        // Add the completed stroke to the strokes list
        widget.strokes.add(_currentStroke!);
        _currentStroke = null;
        _lastEmittedStroke = null;
        _lastEmitTime = null;
        _isDrawing = false;
      });
    } else if (_currentElement != null) {
      // Emit draw event for shapes/text
      SocketService().emitDraw({
        'type': 'element',
        ..._currentElement!.toJson(),
      });
      setState(() {
        widget.elements.add(_currentElement!);
        _currentElement = null;
      });
    }
    _isResizing = false;
    _resizeStartPoint = null;
    _activeResizeHandle = null;
    _isDragging = false;
    _dragStartPoint = null;
    _dragOffset = null;
    
    // Deselect the element after dragging
    if (_isDragging) {
      deselectElement();
    }
  }

  /// Deletes the currently selected element from the canvas.
  void _deleteSelectedElement() {
    if (_selectedElement != null) {
      print('Deleting element with id: [33m${_selectedElement!.id}[0m');
      setState(() {
        // If it's a stroke, emit delete_stroke
        if (_selectedElement is Stroke) {
          final stroke = _selectedElement as Stroke;
          print('Deleting stroke with id: [33m${stroke.id}[0m');
          widget.strokes.removeWhere((s) => s.id == stroke.id);
          SocketService().emitDeleteStroke(stroke.id);
        } else {
          // For elements, emit delete_element
          SocketService().emitDeleteElement(_selectedElement!.id);
        }
        widget.elements.remove(_selectedElement);
        _selectedElement = null;
      });
    }
  }

  /// Deselects the currently selected element.
  void deselectElement() {
    if (_selectedElement != null) {
      setState(() {
        final index = widget.elements.indexOf(_selectedElement!);
        if (index != -1) {
          widget.elements[index] = _selectedElement!.copyWith(
            isSelected: false,
            resizeHandles: null,
            deleteHandle: null,
          );
        }
        _selectedElement = null;
      });
    }
  }

  /// Sets the current drawing color.
  void setColor(Color color) {
    setState(() {
      _currentColor = color;
    });
  }

  /// Sets the current stroke width.
  void setStrokeWidth(double width) {
    setState(() {
      _currentStrokeWidth = width;
    });
  }

  /// Toggles eraser mode.
  void toggleEraser() {
    setState(() {
      _isEraser = !_isEraser;
      if (_isEraser) {
        _currentShapeType = null;
        _currentText = null;
      }
    });
  }

  /// Toggles dashed line mode.
  void toggleDashed() {
    setState(() {
      _isDashed = !_isDashed;
    });
  }

  /// Toggles highlight mode.
  void toggleHighlight() {
    setState(() {
      _isHighlight = !_isHighlight;
    });
  }

  /// Sets the current shape type.
  void setShapeType(ShapeType? type) {
    setState(() {
      _currentShapeType = type;
      if (type != null) {
        _currentText = null;
        _isEraser = false;
      }
    });
  }

  /// Sets the current text to be added.
  void setText(String? text) {
    setState(() {
      _currentText = text;
      if (text != null) {
        _currentShapeType = null;
        _isEraser = false;
      }
    });
  }

  /// Sets the current font size.
  void setFontSize(double size) {
    setState(() {
      _currentFontSize = size;
    });
  }

  /// Sets the current font family.
  void setFontFamily(String family) {
    setState(() {
      _currentFontFamily = family;
    });
  }

  /// Sets the current text alignment.
  void setTextAlignment(TextAlignment alignment) {
    setState(() {
      _currentTextAlignment = alignment;
    });
  }

  /// Sets the current blend mode for highlights.
  void setBlendMode(BlendMode mode) {
    setState(() {
      _currentBlendMode = mode;
    });
  }

  /// Undoes the last drawing operation.
  void undo() {
    setState(() {
      if (widget.strokes.isNotEmpty) {
        _redoStrokes.add(widget.strokes.removeLast());
      } else if (widget.elements.isNotEmpty) {
        _redoElements.add(widget.elements.removeLast());
      }
    });
  }

  /// Redoes the last undone drawing operation.
  void redo() {
    setState(() {
      if (_redoStrokes.isNotEmpty) {
        widget.strokes.add(_redoStrokes.removeLast());
      } else if (_redoElements.isNotEmpty) {
        widget.elements.add(_redoElements.removeLast());
      }
    });
  }

  /// Clears all content from the canvas.
  void clear() {
    setState(() {
      widget.strokes.clear();
      widget.elements.clear();
      _redoStrokes.clear();
      _redoElements.clear();
      _selectedElement = null;
    });
  }

  /// Gets the current scale factor of the canvas.
  double get scale => _scale;

  /// Sets the current scale factor of the canvas.
  set scale(double value) {
    setState(() {
      _scale = value;
    });
  }

  /// Gets the current position of the pointer.
  Offset? get currentPosition => _currentPosition;

  /// Gets the current color.
  Color get currentColor => _currentColor;

  /// Gets the current stroke width.
  double get currentStrokeWidth => _currentStrokeWidth;

  /// Gets whether eraser mode is active.
  bool get isEraser => _isEraser;

  /// Gets whether dashed line mode is active.
  bool get isDashed => _isDashed;

  /// Gets whether highlight mode is active.
  bool get isHighlight => _isHighlight;

  /// Gets the current shape type.
  ShapeType? get currentShapeType => _currentShapeType;

  /// Gets the current text.
  String? get currentText => _currentText;

  /// Gets the current font size.
  double get currentFontSize => _currentFontSize;

  /// Gets the current font family.
  String get currentFontFamily => _currentFontFamily;

  /// Gets the current text alignment.
  TextAlignment get currentTextAlignment => _currentTextAlignment;

  /// Gets the current blend mode.
  BlendMode get currentBlendMode => _currentBlendMode;

  /// Gets the currently selected element.
  de.DrawingElement? get selectedElement => _selectedElement;

  /// Gets whether an element is being resized.
  bool get isResizing => _isResizing;

  @override
  Widget build(BuildContext context) {
    print('WhiteboardState.build called. Strokes count: \x1B[32m${widget.strokes.length}\x1B[0m');
    return Stack(
      children: [
        Listener(
          onPointerMove: (event) {
            setState(() {
              _currentPosition = event.localPosition;
            });
          },
          onPointerDown: (event) {
            setState(() {
              _currentPosition = event.localPosition;
            });
            _startDrawing(event.localPosition);
          },
          onPointerUp: (event) {
            _endDrawing();
          },
          onPointerCancel: (event) {
            _endDrawing();
          },
          child: GestureDetector(
            onPanStart: (details) {
              _startDrawing(details.localPosition);
            },
            onPanUpdate: (details) {
              _draw(details.localPosition);
            },
            onPanEnd: (details) {
              _endDrawing();
            },
            child: CustomPaint(
              painter: DrawingPainter(
                elements: widget.elements,
                currentElement: _currentElement,
                strokes: widget.strokes,
                currentStroke: _currentStroke,
                selectedElement: _selectedElement,
                onImageDecoded: () => setState(() {}),
              ),
              size: Size.infinite,
            ),
          ),
        ),
        // Add eraser circle indicator
        if (_isEraser && _currentPosition != null)
          Positioned(
            left: _currentPosition!.dx - (_currentStrokeWidth * 2),
            top: _currentPosition!.dy - (_currentStrokeWidth * 2),
            child: IgnorePointer(
              child: Container(
                width: _currentStrokeWidth * 4,
                height: _currentStrokeWidth * 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.blue,
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class WhiteboardPage extends StatefulWidget {
  final String roomId;
  final bool isTeacher;

  const WhiteboardPage({
    super.key,
    required this.roomId,
    required this.isTeacher,
  });

  @override
  State<WhiteboardPage> createState() => _WhiteboardPageState();
}

class _WhiteboardPageState extends State<WhiteboardPage> {
  final GlobalKey<WhiteboardState> _whiteboardKey = GlobalKey();
  List<Stroke> _allStrokes = [];
  List<de.DrawingElement> _allElements = [];
  Color _currentColor = Colors.black;
  double _currentStrokeWidth = 2.0;
  String _currentTool = 'pen';
  bool _isToolbarExpanded = true;
  bool _isToolbarOpen = false;
  bool _isEraserMode = false;
  Offset? _currentPosition;

  // Add connection status
  final SocketService _socketService = SocketService();
  bool _isConnected = false;
  bool _isRoomValid = false;
  String? _roomId;
  late bool _isTeacher; // Changed to late initialization

  @override
  void initState() {
    super.initState();
    _isTeacher = widget.isTeacher; // Initialize in initState
    _initializePage();
  }

  void _initializePage() {
    print('\x1B[36mInitializing whiteboard page (Teacher: $_isTeacher)\x1B[0m');

    // Disconnect and clear any existing socket connection
    _socketService.disconnect();
    
    // Force reconnect socket to ensure fresh connection
    _socketService.forceReconnect();

    // Set up connection status listener to join room upon connection
    _socketService.onConnectionStatus((status) {
      print('Connection status changed in WhiteboardPage: $status');
      if (mounted) {
        setState(() {
          _isConnected = status;
          // Reset room validation state when connection changes
          _isRoomValid = false;
        });
      }
      if (status) {
        // Always attempt to join room when connected
        print('\x1B[36mSocket connected, attempting to join room: ${widget.roomId}\x1B[0m');
        _joinRoom(widget.roomId);
      }
    });

    // Set up room validation listener
    SocketService().onRoomValidation((isValid) {
      print('\x1B[36mRoom validation result: $isValid\x1B[0m');
      if (mounted) {
        setState(() {
          _isRoomValid = isValid;
        });
      }

      if (!isValid) {
        // Add mounted check before accessing context
        if (!mounted) return;
        // Show error message if room is invalid
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid room ID. Please check and try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        // Navigate back to room entry if validation fails
        if (mounted) { // Add mounted check before navigation as well
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const RoomEntryScreen(),
            ),
            (route) => false,
          );
        }
      }
    });

    // Set up teacher disconnected listener
    SocketService().socket.on('teacher_disconnected', (_) {
      print('\x1B[31mTeacher disconnected from room\x1B[0m');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Teacher has disconnected from the room.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        // Navigate back to room entry
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const RoomEntryScreen(),
          ),
          (route) => false,
        );
      }
    });

    // Set up room joined listener
    SocketService().socket.on('room_joined', (data) {
      print('\x1B[32mSuccessfully joined room: ${data['roomId']}\x1B[0m');
      if (mounted) {
        setState(() {
          _roomId = data['roomId'];
          _isRoomValid = true; // Room is valid once joined successfully
        });
      }
    });

    // Add error handling for socket connection
    SocketService().socket.on('connect_error', (error) {
      print('\x1B[31mSocket connection error: $error\x1B[0m');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => const RoomEntryScreen(),
          ),
          (route) => false,
        );
      }
    });

    // Listen for delete_stroke events
    _socketService.onDeleteStroke((String strokeId) {
      print('\x1B[32m[${widget.isTeacher ? "TEACHER" : "STUDENT"}] Received delete_stroke event for stroke ID: $strokeId\x1B[0m');
      print('\x1B[36mCurrent strokes before deletion: ${_allStrokes.map((s) => s.id).join(", ")}\x1B[0m');
      
      if (mounted) {
        setState(() {
          // Remove the stroke from the list
          final before = _allStrokes.length;
          _allStrokes.removeWhere((stroke) => stroke.id == strokeId);
          final after = _allStrokes.length;
          
          print('\x1B[35m[${widget.isTeacher ? "TEACHER" : "STUDENT"}] Stroke deletion: before=$before, after=$after\x1B[0m');
          print('\x1B[36mRemaining strokes: ${_allStrokes.map((s) => s.id).join(", ")}\x1B[0m');
          
          // Force rebuild of the whiteboard to update the UI
          if (_whiteboardKey.currentState != null) {
            _whiteboardKey.currentState!.setState(() {});
          }
        });
      }
    });

    // Listen for strokes from the server
    _socketService.onDraw((data) {
      print('onDraw listener triggered in WhiteboardPage. Data: $data');
      if (data['type'] == 'stroke') {
        final points = (data['points'] as List)
            .map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
            .toList();
        final color = Color(data['color'] as int);
        final strokeWidth = (data['strokeWidth'] as num).toDouble();
        final isEraser = data['isEraser'] as bool? ?? false;
        final strokeId = data['id'] as String? ?? const Uuid().v4();
        
        print('[33m[${widget.isTeacher ? "TEACHER" : "STUDENT"}] Received stroke with ID: $strokeId\x1B[0m');
        
        if (mounted) {
          setState(() {
            // Check if stroke already exists
            final existingStrokeIndex = _allStrokes.indexWhere((s) => s.id == strokeId);
            
            if (existingStrokeIndex != -1) {
              // Update existing stroke
              _allStrokes[existingStrokeIndex] = Stroke(
                id: strokeId,
                points: points,
                color: color,
                strokeWidth: strokeWidth,
                isEraser: isEraser,
              );
              print('[33mUpdated existing stroke with ID: $strokeId\x1B[0m');
            } else {
              // Add new stroke
              _allStrokes = List.from(_allStrokes)..add(Stroke(
                id: strokeId,
                points: points,
                color: color,
                strokeWidth: strokeWidth,
                isEraser: isEraser,
              ));
              print('[33mAdded new stroke with ID: $strokeId\x1B[0m');
            }
            
            // Force rebuild of the whiteboard
            if (_whiteboardKey.currentState != null) {
              _whiteboardKey.currentState!.setState(() {});
            }
          });
        }
      } else if (data['type'] == 'element') {
        final element = de.DrawingElement.fromJson(data);
        if (mounted) {
          setState(() {
            _allElements = List.from(_allElements)..add(element);
          });
        }
      }
    });

    // Listen for add_image events
    print('WhiteboardPage initState: registering onAddImage handler');
    _socketService.onAddImage((data) {
      print('WhiteboardPage onAddImage callback triggered');
      print('Data received in onAddImage:');
      print(data);
      print('Type of data: [36m${data.runtimeType}[0m');
      print('imageData length: [35m${data['imageData']?.length}[0m');
      if (mounted) {
        try {
          final element = de.DrawingElement.fromJson(data);
          print('Created DrawingElement: $element');
          setState(() {
            _allElements = List.from(_allElements)..add(element);
          });
        } catch (e, stack) {
          print('Error creating DrawingElement from add_image: $e');
          print(stack);
        }
      }
    });
    print('WhiteboardPage initState: onAddImage handler registered');

    // Listen for clear events from the server
    _socketService.onClear(() {
      if (mounted) {
        setState(() {
          _allStrokes = [];
          _allElements = [];
          _whiteboardKey.currentState?.clear();
        });
      }
    });

    // Listen for move_element events
    _socketService.onMoveElement((data) {
      print('Received move_element event: $data');
      final updatedElement = de.DrawingElement.fromJson(data);
      if (mounted) {
        setState(() {
          _allElements = _allElements.map((e) => e.id == updatedElement.id ? updatedElement : e).toList();
        });
      }
    });

    // Listen for delete_element events
    _socketService.onDeleteElement((String elementId) {
      print('onDeleteElement listener triggered. Removing element with id: [31m$elementId\x1B[0m');
      if (mounted) {
        setState(() {
          final before = _allElements.length;
          _allElements.removeWhere((e) => e.id == elementId);
          print('Elements before: $before, after: ${_allElements.length}');
        });
      }
    });

    // Force reconnect when joining a room
    _socketService.forceReconnect();
  }

  @override
  void dispose() {
    print('WhiteboardPage disposed for room: ${widget.roomId}');
    _socketService.disconnect();
    super.dispose();
  }

  void _handleColorSelected(Color color) {
    setState(() {
      _currentColor = color;
      _whiteboardKey.currentState?.setColor(color);
    });
  }

  void _handleStrokeWidthSelected(double width) {
    setState(() {
      _currentStrokeWidth = width;
      _whiteboardKey.currentState?.setStrokeWidth(width);
    });
  }

  void _handleToolSelected(String tool) {
    setState(() {
      _currentTool = tool;
      switch (tool) {
        case 'pen':
          _whiteboardKey.currentState?.setShapeType(null);
          _whiteboardKey.currentState?.setText(null);
          _whiteboardKey.currentState?.toggleEraser();
          break;
        case 'eraser':
          _whiteboardKey.currentState?.toggleEraser();
          break;
        case 'text':
          _showTextInputDialog();
          break;
        case 'rectangle':
          _whiteboardKey.currentState?.setShapeType(ShapeType.rectangle);
          break;
        case 'circle':
          _whiteboardKey.currentState?.setShapeType(ShapeType.ellipse);
          break;
        case 'line':
          _whiteboardKey.currentState?.setShapeType(ShapeType.line);
          break;
      }
    });
  }

  void _showTextInputDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Text'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Type your text here',
          ),
          onSubmitted: (text) {
            if (text.isNotEmpty) {
              _whiteboardKey.currentState?.setText(text);
            }
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _handleClearSelected() {
    _whiteboardKey.currentState?.clear();
    _socketService.emitClear(); // Emit clear event to all clients
  }

  void _handleUndoSelected() {
    _whiteboardKey.currentState?.undo();
  }

  void _handleRedoSelected() {
    _whiteboardKey.currentState?.redo();
  }

  void _handleSaveSelected() async {
    // Implement save functionality
  }

  void _handleLoadSelected() async {
    // Implement load functionality
  }

  void _handleTextSelected() {
    _showTextInputDialog();
  }

  void _handleShapeSelected(ShapeType type) {
    _whiteboardKey.currentState?.setShapeType(type);
  }

  void _handleEraserSelected() {
    _whiteboardKey.currentState?.toggleEraser();
  }

  // Add empty handlers for other toolbar actions
  void _handleImageSelected() {}
  void _handleBackgroundSelected() {}
  void _handleExportSelected() {}
  void _handleShareSelected() {}
  void _handleSettingsSelected() {}
  void _handleHelpSelected() {}
  void _handleAboutSelected() {}
  void _handleFeedbackSelected() {}
  void _handleReportSelected() {}
  void _handleContactSelected() {}
  void _handlePrivacySelected() {}
  void _handleTermsSelected() {}
  void _handleLogoutSelected() {}
  void _handleProfileSelected() {}
  void _handleNotificationsSelected() {}
  void _handleMessagesSelected() {}
  void _handleCalendarSelected() {}
  void _handleTasksSelected() {}
  void _handleNotesSelected() {}
  void _handleFilesSelected() {}
  void _handleSearchSelected() {}
  void _handleFilterSelected() {}
  void _handleSortSelected() {}
  void _handleViewSelected() {}
  void _handleEditSelected() {}
  void _handleDeleteSelected() {}
  void _handleCopySelected() {}
  void _handlePasteSelected() {}
  void _handleCutSelected() {}
  void _handleSelectAllSelected() {}
  void _handleDeselectAllSelected() {}
  void _handleGroupSelected() {}
  void _handleUngroupSelected() {}
  void _handleLockSelected() {}
  void _handleUnlockSelected() {}
  void _handleHideSelected() {}
  void _handleShowSelected() {}
  void _handleDuplicateSelected() {}
  void _handleAlignSelected() {}
  void _handleDistributeSelected() {}
  void _handleBringToFrontSelected() {}
  void _handleSendToBackSelected() {}
  void _handleBringForwardSelected() {}
  void _handleSendBackwardSelected() {}
  void _handleFlipHorizontalSelected() {}
  void _handleFlipVerticalSelected() {}
  void _handleRotateLeftSelected() {}
  void _handleRotateRightSelected() {}
  void _handleResetRotationSelected() {}
  void _handleResetScaleSelected() {}
  void _handleResetPositionSelected() {}
  void _handleResetAllSelected() {}
  void _handleCustomizeSelected() {}
  void _handlePreferencesSelected() {}
  void _handleShortcutsSelected() {}
  void _handleThemesSelected() {}
  void _handleLanguagesSelected() {}
  void _handleUpdatesSelected() {}
  void _handleBackupSelected() {}
  void _handleRestoreSelected() {}
  void _handleImportSelected() {}
  void _handlePrintSelected() {}
  void _handleEmailSelected() {}
  void _handleSMSSelected() {}
  void _handleCallSelected() {}
  void _handleVideoSelected() {}
  void _handleAudioSelected() {}
  void _handleDocumentSelected() {}
  void _handleSpreadsheetSelected() {}
  void _handlePresentationSelected() {}
  void _handleDatabaseSelected() {}
  void _handleCodeSelected() {}
  void _handleMarkdownSelected() {}
  void _handleHTMLSelected() {}
  void _handleCSSSelected() {}
  void _handleJavaScriptSelected() {}
  void _handlePythonSelected() {}
  void _handleJavaSelected() {}
  void _handleCppSelected() {}
  void _handleCSharpSelected() {}
  void _handleRubySelected() {}
  void _handlePHPSelected() {}
  void _handleSwiftSelected() {}
  void _handleKotlinSelected() {}
  void _handleGoSelected() {}
  void _handleRustSelected() {}
  void _handleScalaSelected() {}
  void _handleHaskellSelected() {}
  void _handleClojureSelected() {}
  void _handleErlangSelected() {}
  void _handleElixirSelected() {}
  void _handleFSharpSelected() {}
  void _handleOCamlSelected() {}
  void _handleRacketSelected() {}
  void _handleSchemeSelected() {}
  void _handleLispSelected() {}
  void _handlePrologSelected() {}
  void _handleSmalltalkSelected() {}
  void _handleObjectiveCSelected() {}
  void _handlePerlSelected() {}
  void _handleLuaSelected() {}
  void _handleJuliaSelected() {}
  void _handleRSelected() {}
  void _handleMATLABSelected() {}
  void _handleOctaveSelected() {}
  void _handleScilabSelected() {}
  void _handleMaximaSelected() {}
  void _handleMapleSelected() {}
  void _handleMathematicaSelected() {}
  void _handleSageSelected() {}
  void _handleGAPSelected() {}
  void _handleMagmaSelected() {}
  void _handleSingularSelected() {}
  void _handleMacaulay2Selected() {}
  void _handleCoCoASelected() {}
  void _handleGfanSelected() {}
  void _handle4ti2Selected() {}
  void _handleNormalizSelected() {}
  void _handlePolymakeSelected() {}
  void _handleTOPCOMSelected() {}
  void _handlePHCpackSelected() {}
  void _handleBertiniSelected() {}

  void _showRoomInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Room Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room ID: ${widget.roomId}'),
            const SizedBox(height: 8),
            Text('Role: ${widget.isTeacher ? "Teacher" : "Student"}'),
            if (widget.isTeacher) ...[
              const SizedBox(height: 16),
              const Text(
                'Share this Room ID with your students to let them join the session.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const RoomEntryScreen(),
                ),
                (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndAddImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        print('Original image bytes length: [33m${bytes.length}[0m');
        // Decode image
        final originalImage = img.decodeImage(bytes);
        if (originalImage == null) {
          print('Failed to decode image');
          return;
        }
        // Resize to max 800px width (maintain aspect ratio)
        final resizedImage = img.copyResize(originalImage, width: 800);
        // Encode back to bytes as JPEG
        final resizedBytes = img.encodeJpg(resizedImage, quality: 80);
        print('Resized image bytes length: [32m${resizedBytes.length}[0m');
        final base64Image = base64Encode(resizedBytes);
        final element = de.DrawingElement(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          startPoint: Offset(100, 100),
          endPoint: Offset(300, 300),
          color: Colors.transparent,
          strokeWidth: 1,
          imageData: base64Image,
          imageWidth: 200,
          imageHeight: 200,
        );
        setState(() {
          _allElements.add(element);
        });
        // Emit to socket for real-time sync (images only)
        print('Emitting add_image event');
        _socketService.emitAddImage(element.toJson());
      }
    } catch (e, stack) {
      print('Error in _pickAndAddImage: $e');
      print(stack);
    }
  }

  void _toggleEraserMode() {
    setState(() {
      _isEraserMode = !_isEraserMode;
      if (_isEraserMode) {
        // Disable other tools when eraser is active
        _currentTool = 'eraser';
        _whiteboardKey.currentState?.setShapeType(null);
        _whiteboardKey.currentState?.setText(null);
      }
    });
  }

  void _deleteStrokeAtPosition(Offset position) {
    if (!_isRoomValid) {
      print('\x1B[31mCannot delete stroke: room not validated\x1B[0m');
      return;
    }
    if (!_isEraserMode || !widget.isTeacher) return;

    final eraserRadius = 20.0; // Fixed eraser size for app bar eraser
    final eraserRadiusSquared = eraserRadius * eraserRadius;
    final socketService = SocketService();
    final strokesToRemove = <Stroke>[];

    // Find strokes that intersect with the eraser
    final candidates = _allStrokes.where((stroke) {
      return stroke.points.any((point) => 
        Rect.fromCenter(
          center: position, 
          width: eraserRadius * 2, 
          height: eraserRadius * 2
        ).contains(point)
      );
    }).toList();

    // Check each candidate stroke for precise intersection
    for (final stroke in candidates) {
      bool shouldRemove = false;
      for (final point in stroke.points) {
        final dx = point.dx - position.dx;
        final dy = point.dy - position.dy;
        if ((dx * dx + dy * dy) <= eraserRadiusSquared) {
          shouldRemove = true;
          break;
        }
      }
      if (shouldRemove) {
        strokesToRemove.add(stroke);
      }
    }

    // Remove strokes and emit delete events
    for (final stroke in strokesToRemove) {
      print('\x1B[33m[TEACHER] Emitting delete_stroke event for stroke ID: ${stroke.id}\x1B[0m');
      setState(() {
        _allStrokes.remove(stroke);
      });
      socketService.emitDeleteStroke(stroke.id);
    }
  }

  void _joinRoom(String roomId) {
    print('\x1B[36mAttempting to join room: $roomId\x1B[0m');
    SocketService().joinRoom(roomId, _isTeacher);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Room: ${widget.roomId}'),
                if (widget.isTeacher) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.school, size: 20),
                ] else ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.person, size: 20),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: _isConnected ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (widget.isTeacher) ...[
            IconButton(
              icon: Icon(
                _isEraserMode ? Icons.auto_fix_high : Icons.auto_fix_normal,
                color: _isEraserMode ? Colors.blue : null,
              ),
              tooltip: _isEraserMode ? 'Exit Eraser Mode' : 'Enter Eraser Mode',
              onPressed: _toggleEraserMode,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Room Info',
            onPressed: _showRoomInfoDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
          if (widget.isTeacher)
            IconButton(
              icon: Icon(_isToolbarOpen ? Icons.close : Icons.menu),
              tooltip: _isToolbarOpen ? 'Close Toolbar' : 'Open Toolbar',
              onPressed: () {
                setState(() {
                  _isToolbarOpen = !_isToolbarOpen;
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: !widget.isTeacher,
            child: GestureDetector(
              onPanUpdate: _isEraserMode ? (details) {
                setState(() {
                  _currentPosition = details.localPosition;
                });
                _deleteStrokeAtPosition(details.localPosition);
              } : null,
              onPanStart: _isEraserMode ? (details) {
                setState(() {
                  _currentPosition = details.localPosition;
                });
              } : null,
              onPanEnd: _isEraserMode ? (details) {
                setState(() {
                  _currentPosition = null;
                });
              } : null,
              child: Whiteboard(
                key: _whiteboardKey,
                strokes: _allStrokes,
                elements: _allElements,
                onStrokeDrawn: (stroke) {
                  print('Emitting stroke with ID: ${stroke.id}');
                  _socketService.emitDraw({
                    'type': 'stroke',
                    'id': stroke.id,
                    'points': stroke.points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
                    'color': stroke.color.value,
                    'strokeWidth': stroke.strokeWidth,
                    'isEraser': stroke.isEraser,
                  });
                  setState(() {
                    // Check if stroke already exists
                    final existingStrokeIndex = _allStrokes.indexWhere((s) => s.id == stroke.id);
                    if (existingStrokeIndex != -1) {
                      _allStrokes[existingStrokeIndex] = stroke;
                    } else {
                      _allStrokes.add(stroke);
                    }
                  });
                },
                isTeacher: widget.isTeacher,
                onImageSelected: _pickAndAddImage,
              ),
            ),
          ),
          if (_isEraserMode && widget.isTeacher && _currentPosition != null)
            Positioned(
              left: _currentPosition!.dx - 20,
              top: _currentPosition!.dy - 20,
              child: IgnorePointer(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          if (widget.isTeacher)
            Positioned(
              top: 16,
              left: 16,
              child: AnimatedSlide(
                offset: _isToolbarOpen ? Offset.zero : const Offset(-1.1, 0),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOut,
                child: Toolbar(
                  selectedColor: _currentColor,
                  selectedStrokeWidth: _currentStrokeWidth,
                  isEraser: _whiteboardKey.currentState?.isEraser ?? false,
                  isDashed: _whiteboardKey.currentState?.isDashed ?? false,
                  isHighlight: _whiteboardKey.currentState?.isHighlight ?? false,
                  selectedShapeType: _whiteboardKey.currentState?.currentShapeType,
                  onColorSelected: _handleColorSelected,
                  onStrokeWidthSelected: _handleStrokeWidthSelected,
                  onEraserToggled: _handleEraserSelected,
                  onUndo: _handleUndoSelected,
                  onRedo: _handleRedoSelected,
                  onClear: _handleClearSelected,
                  onDashedToggled: () => _whiteboardKey.currentState?.toggleDashed(),
                  onHighlightToggled: () => _whiteboardKey.currentState?.toggleHighlight(),
                  onShapeTypeSelected: (type) => _whiteboardKey.currentState?.setShapeType(type),
                  onTextAdded: (text) => _whiteboardKey.currentState?.setText(text),
                  onFontSizeChanged: (size) => _whiteboardKey.currentState?.setFontSize(size),
                  onFontFamilyChanged: (family) => _whiteboardKey.currentState?.setFontFamily(family),
                  onTextAlignmentChanged: (align) => _whiteboardKey.currentState?.setTextAlignment(align),
                  onBlendModeChanged: (mode) => _whiteboardKey.currentState?.setBlendMode(mode),
                  onImageSelected: _pickAndAddImage,
                  isTeacher: widget.isTeacher,
                ),
              ),
            ),
        ],
      ),
    );
  }
} 