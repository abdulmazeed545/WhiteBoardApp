import 'package:flutter/material.dart';
import '../widgets/whiteboard.dart';
import 'room_entry_screen.dart';

class WhiteboardScreen extends StatelessWidget {
  final String roomId;
  final bool isTeacher;

  const WhiteboardScreen({
    super.key,
    required this.roomId,
    required this.isTeacher,
  });

  void _handleLogout(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WhiteboardPage(
        roomId: roomId,
        isTeacher: isTeacher,
      ),
    );
  }
} 