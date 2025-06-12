import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:math';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  late IO.Socket socket;
  String? _userId;
  String? _username;
  bool _isConnected = false;
  String? _currentRoomId;
  bool _isTeacher = false;
  final List<Function(Map<String, dynamic>)> _drawListeners = [];
  final List<Function()> _clearListeners = [];
  final List<Function(List<dynamic>)> _userListListeners = [];
  final List<Function(bool)> _connectionStatusListeners = [];
  final List<Function(Map<String, dynamic>)> _moveElementListeners = [];
  final List<Function(Map<String, dynamic>)> _addImageListeners = [];
  final List<Function(String)> _deleteImageListeners = [];
  final List<Function(bool)> _roomValidationListeners = [];
  static const int _maxDrawQueueSize = 5;
  final List<Map<String, dynamic>> _drawQueue = [];
  bool _isProcessingDrawQueue = false;

  factory SocketService() {
    return _instance;
  }

  SocketService._internal() {
    print('SocketService singleton instance created');
    _initSocket();
    socket.onAny((event, data) {
      print('SocketService received event: $event');
      print('SocketService event data: $data');
    });
  }

  void _initSocket() {
    print('Setting up socket connection');
    socket = IO.io('http://localhost:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
    });

    socket.onConnect((_) {
      print('Connected to server with ID: ${socket.id}');
      _userId = socket.id;
      _isConnected = true;
      _notifyConnectionStatus(true);
      // Register onAddImage handler immediately after connection
      print('Registering onAddImage handler on connect');
      socket.on('add_image', (data) {
        print('onAddImage handler triggered with data:');
        print(data);
        for (var listener in _addImageListeners) {
          listener(data);
        }
      });
    });

    socket.onDisconnect((_) {
      print('Disconnected from server');
      _userId = null;
      _isConnected = false;
      _notifyConnectionStatus(false);
    });

    socket.onError((error) {
      print('Socket error: $error');
      _isConnected = false;
      _notifyConnectionStatus(false);
    });

    // Add room validation event listener
    socket.on('room_validation', (data) {
      print('Received room validation response: $data');
      if (data is Map && data['valid'] != null) {
        final isValid = data['valid'] as bool;
        _notifyRoomValidation(isValid);
        if (isValid) {
          print('Room validation successful for room: $_currentRoomId');
        } else {
          print('Room validation failed for room: $_currentRoomId');
          disconnect();
        }
      }
    });

    // Set up event listeners
    socket.on('draw', (data) {
      print('Received draw event: $data');
      for (var listener in _drawListeners) {
        listener(data);
      }
    });

    socket.on('move_element', (data) {
      print('SocketService received move_element: $data');
      for (var listener in _moveElementListeners) {
        listener(data);
      }
    });

    socket.on('clear', (data) {
      print('Received clear event');
      for (var listener in _clearListeners) {
        listener();
      }
    });

    socket.on('user_list', (data) {
      print('Received user list: $data');
      for (var listener in _userListListeners) {
        listener(data);
      }
    });

    socket.on('delete_image', (data) {
      print('Received delete_image event: $data');
      if (data is Map && data['id'] != null) {
        for (var listener in _deleteImageListeners) {
          listener(data['id'] as String);
        }
      }
    });

    socket.onAny((event, data) {
      print('SocketService received event: $event');
    });
  }

  void forceReconnect() {
    print('Force reconnecting socket...');
    if (socket.connected) {
      socket.disconnect();
    }
    socket.dispose();
    _initSocket();
    connect();
  }

  void _notifyConnectionStatus(bool status) {
    for (var listener in _connectionStatusListeners) {
      listener(status);
    }
  }

  void connect() {
    print('Attempting to connect to server...');
    socket.connect();
  }

  void disconnect() {
    if (socket.connected) {
      // Clear all listeners before disconnecting
      _drawListeners.clear();
      _clearListeners.clear();
      _userListListeners.clear();
      _connectionStatusListeners.clear();
      _roomValidationListeners.clear();
      
      // Remove all socket listeners
      socket.off('draw');
      socket.off('clear');
      socket.off('user_list');
      socket.off('move_element');
      socket.off('delete_stroke');
      
      socket.disconnect();
      _userId = null;
      _isConnected = false;
      _currentRoomId = null;
      _isTeacher = false;
      _notifyConnectionStatus(false);
    }
  }

  void joinAsUser(String username) {
    _username = username;
    socket.emit('user_join', username);
  }

  void emitDraw(Map<String, dynamic> data) {
    if (!socket.connected || _currentRoomId == null) return;

    // Add to queue
    _drawQueue.add(data);
    
    // Process queue if not already processing
    if (!_isProcessingDrawQueue) {
      _processDrawQueue();
    }
  }

  void _processDrawQueue() {
    if (_drawQueue.isEmpty) {
      _isProcessingDrawQueue = false;
      return;
    }

    _isProcessingDrawQueue = true;
    
    // Take the latest draw data if queue is too large
    Map<String, dynamic> dataToEmit;
    if (_drawQueue.length > _maxDrawQueueSize) {
      dataToEmit = _drawQueue.last;
      _drawQueue.clear();
    } else {
      dataToEmit = _drawQueue.removeAt(0);
    }

    // Emit the draw data
    socket.emit('draw', dataToEmit);

    // Schedule next processing with shorter delay for better real-time performance
    Future.delayed(const Duration(milliseconds: 8), () {
      _processDrawQueue();
    });
  }

  void emitClear() {
    socket.emit('clear');
  }

  void onDraw(Function(Map<String, dynamic>) callback) {
    _drawListeners.add(callback);
  }

  void onClear(Function() callback) {
    _clearListeners.add(callback);
  }

  void onUserList(Function(List<dynamic>) callback) {
    _userListListeners.add(callback);
  }

  void onConnectionStatus(Function(bool) callback) {
    _connectionStatusListeners.add(callback);
  }

  void emitDeleteStroke(String strokeId) {
    if (!socket.connected || _currentRoomId == null) {
      print('\x1B[31mCannot emit delete_stroke: socket not connected or no room ID\x1B[0m');
      return;
    }
    print('\x1B[33m[SocketService] Emitting delete_stroke event for stroke ID: $strokeId\x1B[0m');
    socket.emit('delete_stroke', {'id': strokeId, 'roomId': _currentRoomId});
    print('\x1B[33m[SocketService] delete_stroke event emitted successfully\x1B[0m');
  }

  void onDeleteStroke(Function(String) callback) {
    print('\x1B[36m[SocketService] Registering delete_stroke listener\x1B[0m');
    // Remove any existing listeners to prevent duplicates
    socket.off('delete_stroke');
    socket.on('delete_stroke', (data) {
      print('\x1B[36m[SocketService] Received delete_stroke event with data: $data\x1B[0m');
      if (data is Map && data['id'] != null) {
        final strokeId = data['id'] as String;
        print('\x1B[36m[SocketService] Processing delete_stroke for ID: $strokeId\x1B[0m');
        callback(strokeId);
      } else {
        print('\x1B[31m[SocketService] Invalid delete_stroke data received: $data\x1B[0m');
      }
    });
  }

  void onMoveElement(Function(Map<String, dynamic>) callback) {
    print('Registering move_element listener');
    _moveElementListeners.add(callback);
  }

  void emitMoveElement(Map<String, dynamic> data) {
    print('Emitting move_element: $data');
    if (socket.connected) {
      socket.emit('move_element', data);
    } else {
      print('Socket not connected, cannot emit move_element');
    }
  }

  void emitDeleteElement(String elementId) {
    print('Emitting delete_element for id: [35m$elementId[0m');
    socket.emit('delete_element', {'id': elementId});
  }

  void onDeleteElement(Function(String) callback) {
    print('Registering onDeleteElement listener');
    socket.on('delete_element', (data) {
      print('Received delete_element event: $data');
      if (data is Map && data['id'] != null) {
        callback(data['id'] as String);
      }
    });
  }

  void emitAddImage(Map<String, dynamic> imageData) {
    socket.emit('add_image', imageData);
  }

  void emitDeleteImage(String imageId) {
    print('Emitting delete_image for id: $imageId');
    socket.emit('delete_image', {'id': imageId});
  }

  void onAddImage(Function(Map<String, dynamic>) callback) {
    print('Registering onAddImage handler');
    _addImageListeners.add(callback);
  }

  void onDeleteImage(Function(String) callback) {
    print('Registering onDeleteImage handler');
    _deleteImageListeners.add(callback);
  }

  String? get userId => _userId;
  String? get username => _username;
  bool get isConnected => _isConnected;

  // Add room validation method
  bool validateRoomId(String roomId, bool isTeacher) {
    print('\x1B[36mValidating room ID: $roomId (Teacher: $isTeacher)\x1B[0m');
    
    // Basic format validation
    if (roomId.isEmpty || roomId.length < 4) {
      print('\x1B[31mInvalid room ID format: too short\x1B[0m');
      return false;
    }

    // Store the current room ID and teacher status
    _currentRoomId = roomId;
    _isTeacher = isTeacher;

    if (isTeacher) {
      // For teachers, generate a new room ID if not provided
      if (roomId.isEmpty) {
        _currentRoomId = _generateRoomId();
        print('\x1B[32mGenerated new room ID: $_currentRoomId\x1B[0m');
      }
      return true;
    } else {
      // For students, validate against the server
      if (socket.connected) {
        socket.emit('validate_room', {'roomId': roomId});
        return true; // Will be updated by server response
      } else {
        print('\x1B[31mCannot validate room: socket not connected\x1B[0m');
        return false;
      }
    }
  }

  String _generateRoomId() {
    // Generate a 6-character room ID
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  void onRoomValidation(Function(bool) callback) {
    _roomValidationListeners.add(callback);
  }

  void _notifyRoomValidation(bool isValid) {
    for (var listener in _roomValidationListeners) {
      listener(isValid);
    }
  }

  void joinRoom(String roomId, bool isTeacher) {
    if (!validateRoomId(roomId, isTeacher)) {
      print('\x1B[31mCannot join room: invalid room ID\x1B[0m');
      return;
    }

    if (socket.connected) {
      print('\x1B[32mJoining room: $roomId (Teacher: $isTeacher)\x1B[0m');
      socket.emit('join_room', {
        'roomId': roomId,
        'isTeacher': isTeacher,
        'username': _username,
      });
    } else {
      print('\x1B[31mCannot join room: socket not connected\x1B[0m');
    }
  }
} 