import 'package:flutter/material.dart';
import 'dart:math';
import 'whiteboard_screen.dart';
import '../services/socket_service.dart';

class RoomEntryScreen extends StatefulWidget {
  const RoomEntryScreen({super.key});

  @override
  State<RoomEntryScreen> createState() => _RoomEntryScreenState();
}

class _RoomEntryScreenState extends State<RoomEntryScreen> {
  String? _selectedRole;
  final TextEditingController _roomIdController = TextEditingController();
  bool _isLoading = false;

  String _generateRoomId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  void _handleTeacherSelection() {
    setState(() {
      _selectedRole = 'teacher';
      _isLoading = true;
    });

    // Generate room ID and navigate to whiteboard
    final roomId = _generateRoomId();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => WhiteboardScreen(
              roomId: roomId,
              isTeacher: true,
            ),
          ),
        );
      }
    });
  }

  void _handleStudentJoin() {
    if (_roomIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Room ID')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Initialize socket service and validate room
    final socketService = SocketService();
    socketService.forceReconnect();

    // Set up validation listener
    socketService.onRoomValidation((isValid) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (isValid) {
          // Navigate to whiteboard only if room is valid
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => WhiteboardScreen(
                roomId: _roomIdController.text,
                isTeacher: false,
              ),
            ),
          );
        } else {
          // Show error message if room is invalid
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid room ID. Please check and try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });

    // Set up connection listener
    socketService.onConnectionStatus((status) {
      if (status) {
        // Validate room when connected
        socketService.validateRoomId(_roomIdController.text, false);
      }
    });

    // Connect to socket
    socketService.connect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade100,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Welcome to Whiteboard',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _buildRoleSelection(),
                  const SizedBox(height: 32),
                  if (_selectedRole == 'student') _buildRoomIdInput(),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else if (_selectedRole == 'student')
                    ElevatedButton(
                      onPressed: _handleStudentJoin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                      ),
                      child: const Text(
                        'Join Room',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _selectedRole == null ? _handleTeacherSelection : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedRole == 'teacher' ? Colors.blue : Colors.grey,
            padding: const EdgeInsets.symmetric(
              horizontal: 48,
              vertical: 16,
            ),
          ),
          child: const Text(
            'I am a Teacher',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _selectedRole = 'student';
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedRole == 'student' ? Colors.blue : Colors.grey,
            padding: const EdgeInsets.symmetric(
              horizontal: 48,
              vertical: 16,
            ),
          ),
          child: const Text(
            'I am a Student',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoomIdInput() {
    return Column(
      children: [
        const Text(
          'Enter Room ID',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _roomIdController,
          decoration: InputDecoration(
            hintText: 'Enter the Room ID provided by your teacher',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    super.dispose();
  }
} 