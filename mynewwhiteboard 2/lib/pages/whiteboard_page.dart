import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';

import '../models/drawing_element.dart';
import '../painters/drawing_painter.dart';
import '../services/socket_service.dart';
import '../widgets/whiteboard.dart';

class WhiteboardPage extends StatefulWidget {
  final bool isTeacher;
  const WhiteboardPage({Key? key, required this.isTeacher}) : super(key: key);

  @override
  State<WhiteboardPage> createState() => _WhiteboardPageState();
}

class _WhiteboardPageState extends State<WhiteboardPage> {
  final SocketService _socketService = SocketService();
  final List<DrawingElement> _allElements = [];
  final List<Stroke> _allStrokes = [];
  final GlobalKey<WhiteboardState> _whiteboardKey = GlobalKey();
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    print('WhiteboardPage initState called');
    _setupSocketListeners();
  }

  @override
  void dispose() {
    print('WhiteboardPage dispose called');
    _mounted = false;
    super.dispose();
  }

  void _setupSocketListeners() {
    print('Setting up socket listeners');
    
    // Draw listener
    _socketService.onDraw((data) {
      if (!_mounted) return;
      print('onDraw listener triggered in WhiteboardPage. Data: $data');
      setState(() {
        if (data['type'] == 'element') {
          final element = DrawingElement.fromJson(data);
          _allElements.add(element);
          print('Added new element. Total elements: [32m${_allElements.length}[0m');
        }
        // Handle other draw types...
      });
    });

    // Move element listener
    _socketService.onMoveElement((data) {
      print('Move element listener triggered with data: $data');
      if (!_mounted) {
        print('Widget not mounted, ignoring move_element event');
        return;
      }
      setState(() {
        try {
          final updatedElement = DrawingElement.fromJson(data);
          print('Updating element with ID: ${updatedElement.id}');
          _allElements.removeWhere((e) => e.id == updatedElement.id);
          _allElements.add(updatedElement);
          print('Element updated successfully. Total elements: ${_allElements.length}');
        } catch (e) {
          print('Error processing move_element event: $e');
        }
      });
    });

    // Connection status listener
    _socketService.onConnectionStatus((isConnected) {
      print('Connection status changed: $isConnected');
    });

    // Listen for delete_element events
    _socketService.onDeleteElement((String elementId) {
      print('onDeleteElement listener triggered. Removing element with id: \x1B[31m$elementId\x1B[0m');
      setState(() {
        final before = _allElements.length;
        _allElements.removeWhere((e) => e.id == elementId);
        print('Elements before: $before, after: ${_allElements.length}');
      });
    });
  }

  Future<void> _pickAndAddImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final element = DrawingElement(
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
      // Optionally, emit to socket for real-time sync
      _socketService.emitDraw({
        'type': 'element',
        ...element.toJson(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('WhiteboardPage build called with [32m${_allElements.length}[0m elements');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Room: Whiteboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.image),
            tooltip: 'Add Image',
            onPressed: _pickAndAddImage,
          ),
        ],
      ),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: !widget.isTeacher,
            child: Whiteboard(
              key: _whiteboardKey,
              strokes: _allStrokes,
              elements: _allElements,
              onStrokeDrawn: (stroke) {
                _socketService.emitDraw({
                  'type': 'stroke',
                  'points': stroke.points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
                  'color': stroke.color.value,
                  'strokeWidth': stroke.strokeWidth,
                });
                setState(() {
                  _allStrokes.add(stroke);
                });
              },
              isTeacher: widget.isTeacher,
              onImageSelected: _pickAndAddImage,
            ),
          ),
          // ... rest of your UI
        ],
      ),
    );
  }
} 