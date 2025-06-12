/// A Flutter whiteboard application that provides drawing, text, and shape tools
/// with features like saving, loading, and exporting as images.

import 'package:flutter/material.dart';
import 'screens/room_entry_screen.dart';
// Remove unused imports
// import 'widgets/whiteboard.dart';
// import 'widgets/toolbar.dart';
// import 'services/file_service.dart';
// import 'services/image_service.dart';
// import 'models/drawing_element.dart';
// import 'models/shape_type.dart';
// import 'services/socket_service.dart';

void main() {
  runApp(const MyApp());
}

/// The root widget of the application that sets up the Material theme
/// and initializes the whiteboard page.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whiteboard App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const RoomEntryScreen(),
    );
  }
}

// Removed minimal WhiteboardPage and DrawingPainter classes from main.dart.
// Navigation to the whiteboard should use the advanced WhiteboardPage from pages/whiteboard_page.dart.
