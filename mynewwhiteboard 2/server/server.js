const express = require('express');
const app = express();
const http = require('http').createServer(app);
const io = require('socket.io')(http, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Serve static files
app.use(express.static('public'));

// Store connected users
const connectedUsers = new Map();

// Store active rooms and their teachers
const activeRooms = new Map();

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);

  // Handle room validation
  socket.on('validate_room', (data) => {
    console.log('Validating room:', data);
    const { roomId } = data;
    
    // Check if room exists and has a teacher
    const isValid = activeRooms.has(roomId) && activeRooms.get(roomId).hasTeacher;
    
    console.log(`Room ${roomId} validation result:`, isValid);
    socket.emit('room_validation', { valid: isValid });
  });

  // Handle joining room
  socket.on('join_room', (data) => {
    const { roomId, isTeacher, username } = data;
    console.log(`User ${socket.id} (${username}) joining room ${roomId} as ${isTeacher ? 'teacher' : 'student'}`);

    if (isTeacher) {
      // Initialize room if it doesn't exist
      if (!activeRooms.has(roomId)) {
        activeRooms.set(roomId, {
          hasTeacher: true,
          teacherId: socket.id,
          students: new Set()
        });
        console.log(`Room ${roomId} created by teacher ${socket.id}`);
      }
    } else {
      // For students, check if room exists and has a teacher
      const room = activeRooms.get(roomId);
      if (!room || !room.hasTeacher) {
        console.log(`Student ${socket.id} attempted to join invalid room ${roomId}`);
        socket.emit('room_validation', { valid: false });
        return;
      }
      room.students.add(socket.id);
      console.log(`Student ${socket.id} joined room ${roomId}`);
    }

    // Join the socket room
    socket.join(roomId);
    socket.emit('room_joined', { roomId, isTeacher });
  });

  // Handle disconnection
  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
    
    // Check if disconnecting user is a teacher
    for (const [roomId, room] of activeRooms.entries()) {
      if (room.teacherId === socket.id) {
        // Teacher disconnected, notify all students and remove room
        io.to(roomId).emit('teacher_disconnected');
        activeRooms.delete(roomId);
        console.log(`Room ${roomId} removed due to teacher disconnect`);
      } else if (room.students.has(socket.id)) {
        // Student disconnected, remove from room
        room.students.delete(socket.id);
        console.log(`Student ${socket.id} removed from room ${roomId}`);
      }
    }
  });

  // Handle drawing events
  socket.on('draw', (data) => {
    // Get the room ID from the socket's rooms
    const rooms = Array.from(socket.rooms);
    const roomId = rooms.find(room => room !== socket.id); // Get the room ID (excluding socket's own ID)
    
    if (roomId) {
      // Broadcast the drawing data only to clients in the same room
      socket.to(roomId).emit('draw', {
        ...data,
        userId: socket.id
      });
    }
  });

  // Handle delete_stroke event
  socket.on('delete_stroke', (data) => {
    console.log('\x1b[33m[Server] Received delete_stroke event from client:', socket.id, 'Data:', data, '\x1b[0m');
    const rooms = Array.from(socket.rooms);
    const roomId = rooms.find(room => room !== socket.id);
    
    if (roomId) {
      socket.to(roomId).emit('delete_stroke', data);
      console.log('\x1b[32m[Server] Broadcasted delete_stroke event to room: ${roomId}\x1b[0m');
    }
  });

  // Handle clear canvas event
  socket.on('clear', () => {
    const rooms = Array.from(socket.rooms);
    const roomId = rooms.find(room => room !== socket.id);
    
    if (roomId) {
      socket.to(roomId).emit('clear', { userId: socket.id });
    }
  });

  // Handle user joining
  socket.on('user_join', (username) => {
    connectedUsers.set(socket.id, { id: socket.id, username });
    io.emit('user_list', Array.from(connectedUsers.values()));
  });

  // Handle errors
  socket.on('error', (error) => {
    console.error('Socket error:', error);
  });

  // Handle move_element event
  socket.on('move_element', (data) => {
    console.log('Relaying move_element:', data);
    const rooms = Array.from(socket.rooms);
    const roomId = rooms.find(room => room !== socket.id);
    
    if (roomId) {
      socket.to(roomId).emit('move_element', data);
    }
  });

  // Handle delete_element event
  socket.on('delete_element', (data) => {
    console.log('Broadcasting delete_element:', data);
    socket.broadcast.emit('delete_element', data);
  });

  // Handle add_image event
  socket.on('add_image', (data) => {
    console.log('Received add_image event:', data);
    const rooms = Array.from(socket.rooms);
    const roomId = rooms.find(room => room !== socket.id);
    
    if (roomId) {
      socket.to(roomId).emit('add_image', data);
      console.log('Broadcasted add_image event to room:', roomId);
    } else {
      console.log('No room found for socket:', socket.id);
    }
  });
});

const PORT = process.env.PORT || 3000;
http.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Socket.IO server is ready for connections`);
}); 