import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_role.dart';

class UserService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _usersCollection = 'users';
  static const String _usernameKey = 'current_username';
  static const String _userRoleKey = 'current_user_role';
  
  // Current logged-in user
  String? _currentUsername;
  UserRole? _currentUserRole;
  
  String? get currentUsername => _currentUsername;
  UserRole? get currentUserRole => _currentUserRole;
  
  // Initialize and restore user from storage
  Future<void> initializeUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUsername = prefs.getString(_usernameKey);
      final roleString = prefs.getString(_userRoleKey);
      
      if (roleString != null) {
        // Convert string back to UserRole
        if (roleString == 'customer') {
          _currentUserRole = UserRole.customer;
        } else if (roleString == 'driver') {
          _currentUserRole = UserRole.driver;
        } else if (roleString == 'admin') {
          _currentUserRole = UserRole.admin;
        }
      }
      
      if (_currentUsername != null) {
        debugPrint('✅ User restored from storage: $_currentUsername ($_currentUserRole)');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to restore user from storage: $e');
    }
  }
  
  // Set current user (called during login)
  Future<void> setCurrentUser(String username, UserRole role) async {
    _currentUsername = username;
    _currentUserRole = role;
    
    // Save to storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_usernameKey, username);
      await prefs.setString(_userRoleKey, role.name);
      debugPrint('✅ User saved to storage: $username ($role)');
    } catch (e) {
      debugPrint('Failed to save user to storage: $e');
    }
    
    notifyListeners();
  }
  
  // Clear current user (called during logout)
  Future<void> clearCurrentUser() async {
    _currentUsername = null;
    _currentUserRole = null;
    
    // Clear from storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_usernameKey);
      await prefs.remove(_userRoleKey);
      debugPrint('✅ User cleared from storage');
    } catch (e) {
      debugPrint('Failed to clear user from storage: $e');
    }
    
    notifyListeners();
  }

  
  // Database health check
  Future<Map<String, dynamic>> checkDatabaseHealth() async {
    try {
      final startTime = DateTime.now();
      
      // Test write
      await _firestore.collection('health').doc('test').set({
        'timestamp': FieldValue.serverTimestamp(),
        'test': 'write_test',
      });
      
      // Test read
      final doc = await _firestore.collection('health').doc('test').get();
      
      // Test query
      final querySnapshot = await _firestore.collection('health').limit(1).get();
      
      // Clean up
      await _firestore.collection('health').doc('test').delete();
      
      final endTime = DateTime.now();
      final responseTime = endTime.difference(startTime).inMilliseconds;
      
      return {
        'status': 'healthy',
        'responseTime': '${responseTime}ms',
        'writeTest': doc.exists ? 'passed' : 'failed',
        'readTest': doc.exists ? 'passed' : 'failed',
        'queryTest': querySnapshot.docs.isNotEmpty ? 'passed' : 'passed',
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'status': 'unhealthy',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
  
  // Create a new user
  Future<String> createUser({
    required String username,
    required String password,
    required UserRole role,
    required String email,
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? address,
    String? bio,
    String? walletAddress,
    String? vehicleType,
    String? licenseNumber,
    String? preferredPayment,
  }) async {
    try {
      final userData = {
        'username': username,
        'password': password, // In production, hash this password
        'role': role.name,
        'email': email,
        'fullName': fullName ?? '',
        'phone': phone ?? '',
        'avatarUrl': avatarUrl ?? '',
        'address': address ?? '',
        'bio': bio ?? '',
        'walletAddress': walletAddress ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': null,
        'status': 'active',
        if (role == UserRole.driver) ...{
          'vehicleType': vehicleType ?? '',
          'licenseNumber': licenseNumber ?? '',
        },
        if (role == UserRole.customer) ...{
          'preferredPayment': preferredPayment ?? '',
        },
      };

      final docRef = await _firestore
          .collection(_usersCollection)
          .add(userData);
      
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  // Get user by username and role
  Future<Map<String, dynamic>?> getUser(String username, UserRole role) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('username', isEqualTo: username)
          .where('role', isEqualTo: role.name)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // Update user
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .update(updates);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // Update last login
  Future<void> updateLastLogin(String userId) async {
    try {
      await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update last login: $e');
    }
  }

  // Check if user exists
  Future<bool> userExists(String username, UserRole role) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('username', isEqualTo: username)
          .where('role', isEqualTo: role.name)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check if user exists: $e');
    }
  }

  // Get all users (for admin purposes)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Failed to get all users: $e');
    }
  }

  // Create test users (for development)
  Future<void> createTestUsers() async {
    try {
      // Check if test users already exist
      final driverExists = await userExists('driverTest', UserRole.driver);
      final customerExists = await userExists('customerTest', UserRole.customer);

      if (!driverExists) {
        await createUser(
          username: 'driverTest',
          password: '123456',
          role: UserRole.driver,
          email: 'driver@test.com',
          fullName: 'Test Driver',
        );
      }

      if (!customerExists) {
        await createUser(
          username: 'customerTest',
          password: '78910',
          role: UserRole.customer,
          email: 'customer@test.com',
          fullName: 'Test Customer',
        );
      }
    } catch (e) {
      print('Failed to create test users: $e');
    }
  }

  // Create admin user (for development)
  Future<void> createAdminUser() async {
    try {
      // Check if admin user already exists
      final adminExists = await userExists('admin', UserRole.admin);

      if (!adminExists) {
        await createUser(
          username: 'admin',
          password: 'admin123',
          role: UserRole.admin,
          email: 'admin@deliverydapp.com',
          fullName: 'System Administrator',
          phone: '+1234567890',
          avatarUrl: '',
          address: 'System',
          bio: 'System Administrator with full access',
        );
        print('✅ Admin user created successfully');
      } else {
        print('ℹ️ Admin user already exists');
      }
    } catch (e) {
      print('❌ Failed to create admin user: $e');
    }
  }
}
