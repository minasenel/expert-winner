import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Enable test mode for development
const bool kTestMode = true;

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  
  /// Hashes the password using SHA-256 algorithm
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Sanitize phone number for use as a key in Firebase
  String _sanitizePhoneNumber(String phoneNumber) {
    // Remove non-alphanumeric characters for Firebase key safety
    return phoneNumber.replaceAll(RegExp(r'[^\w]'), '');
  }
  
  /// Save user data to Firebase Realtime Database
  Future<void> saveUserData(String phoneNumber, String password) async {
    try {
      final User? user = _auth.currentUser;
      print('Current user: ${user?.uid ?? "none"}');
      print('Phone number to save: $phoneNumber');
      
      final String hashedPassword = _hashPassword(password);
      
      // In test mode or if no authenticated user, save to tempUsers
      if (user == null) {
        if (!kTestMode) {
          throw Exception('No authenticated user found. Please sign in first.');
        }
        
        print('Test mode: Saving user data to temporary path');
        final String sanitizedPhone = _sanitizePhoneNumber(phoneNumber);
        
        // Create a reference to the temporary user's data node
        DatabaseReference tempUserRef = _databaseRef.child('tempUsers/$sanitizedPhone');
        
        Map<String, dynamic> userData = {
          "phone": phoneNumber,
          "password": hashedPassword,
          "createdAt": ServerValue.timestamp,
          "isTemporary": true,
          "tempId": sanitizedPhone
        };
        
        print('Data to save to tempUsers: $userData');
        
        // Set the temporary user data
        await tempUserRef.set(userData);
        
        // Save tempId in SharedPreferences for easier access
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('phoneNumber', phoneNumber);
        await prefs.setString('tempUserId', sanitizedPhone);
        await prefs.setBool('isTemporary', true);
        
        print('User data saved successfully to Firebase temporary path');
        return;
      }
      
      // For authenticated users, save to regular users path
      final String userId = user.uid;
      
      print('Saving user data for authenticated user ID: $userId');
      
      // Create a reference to the user's data node
      DatabaseReference userRef = _databaseRef.child('users/$userId');
      
      Map<String, dynamic> userData = {
        "phone": phoneNumber,
        "password": hashedPassword,
        "createdAt": ServerValue.timestamp,
        "uid": userId,
        "isTemporary": false
      };
      
      print('Data to save: $userData');
      
      // Set the user data
      await userRef.set(userData);
      
      // Save phone number in SharedPreferences for easier access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phoneNumber', phoneNumber);
      await prefs.setString('userId', userId);
      await prefs.setBool('isTemporary', false);
      
      print('User data saved successfully to Firebase');
    } catch (e) {
      print('Error saving user data to Firebase: $e');
      print('Error stack trace: ${e is Error ? e.stackTrace : "Not available"}');
      throw e;
    }
  }
  
  /// Get user phone number from Firebase or SharedPreferences
  Future<String?> getUserPhoneNumber() async {
    try {
      // First try to get from SharedPreferences for faster access
      final prefs = await SharedPreferences.getInstance();
      final cachedPhone = prefs.getString('phoneNumber');
      
      if (cachedPhone != null && cachedPhone.isNotEmpty) {
        return cachedPhone;
      }
      
      // If not in SharedPreferences, try to get from Firebase
      final User? user = _auth.currentUser;
      
      // In test mode, check tempUsers if there's no authenticated user
      if (user == null && kTestMode) {
        final tempUserId = prefs.getString('tempUserId');
        if (tempUserId != null) {
          DatabaseReference tempUserRef = _databaseRef.child('tempUsers/$tempUserId');
          DatabaseEvent event = await tempUserRef.once();
          
          if (event.snapshot.exists) {
            final userData = event.snapshot.value as Map<dynamic, dynamic>?;
            final phoneNumber = userData?['phone'] as String?;
            return phoneNumber;
          }
        }
        return null;
      }
      
      // Not in test mode or authenticated user exists
      if (user == null) {
        return null;
      }
      
      final String userId = user.uid;
      
      // Get user data from Firebase
      DatabaseReference userRef = _databaseRef.child('users/$userId');
      DatabaseEvent event = await userRef.once();
      
      if (event.snapshot.exists) {
        // Extract phone number from snapshot
        final userData = event.snapshot.value as Map<dynamic, dynamic>?;
        final phoneNumber = userData?['phone'] as String?;
        
        // Cache it for future use
        if (phoneNumber != null) {
          await prefs.setString('phoneNumber', phoneNumber);
        }
        
        return phoneNumber;
      }
      
      // Return the phone number from Firebase Auth as a fallback
      return user.phoneNumber;
    } catch (e) {
      print('Error getting user phone number: $e');
      return null;
    }
  }
  
  /// Save user personal details to Firebase Realtime Database
  Future<void> saveUserDetails(String firstName, String lastName, String dateOfBirth, String gender) async {
    try {
      final User? user = _auth.currentUser;
      print('Current user: ${user?.uid ?? "none"}');
      
      // In test mode, handle case with no authenticated user
      if (user == null) {
        if (!kTestMode) {
          throw Exception('No authenticated user found. Please sign in first.');
        }
        
        // Get temporary user ID from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final tempUserId = prefs.getString('tempUserId');
        final phoneNumber = prefs.getString('phoneNumber');
        
        if (tempUserId == null || phoneNumber == null) {
          throw Exception('No temporary user found. Please create a password first.');
        }
        
        print('Test mode: Saving user details to temporary path for phone: $phoneNumber');
        
        // Create a reference to the temporary user's data node
        DatabaseReference tempUserRef = _databaseRef.child('tempUsers/$tempUserId');
        
        // Get current temporary user data first
        DatabaseEvent event = await tempUserRef.once();
        Map<String, dynamic> userData = {};
        
        if (event.snapshot.exists) {
          // Preserve existing data
          final existingData = event.snapshot.value as Map<dynamic, dynamic>;
          existingData.forEach((key, value) {
            userData[key.toString()] = value;
          });
        }
        
        // Add or update personal details
        userData.addAll({
          "firstName": firstName,
          "lastName": lastName,
          "dateOfBirth": dateOfBirth,
          "gender": gender,
          "profileCompleted": true,
          "updatedAt": ServerValue.timestamp,
        });
        
        print('Data to save to tempUsers: $userData');
        
        // Update the temporary user data
        await tempUserRef.update(userData);
        
        print('User details saved successfully to Firebase temporary path');
        return;
      }
      
      // Get the authenticated user ID for regular users path
      final String userId = user.uid;
      
      print('Saving user details for user ID: $userId');
      
      // Create a reference to the user's data node
      DatabaseReference userRef = _databaseRef.child('users/$userId');
      
      // Get current user data first
      DatabaseEvent event = await userRef.once();
      Map<String, dynamic> userData = {};
      
      if (event.snapshot.exists) {
        // Preserve existing data
        final existingData = event.snapshot.value as Map<dynamic, dynamic>;
        existingData.forEach((key, value) {
          userData[key.toString()] = value;
        });
      }
      
      // Add or update personal details
      userData.addAll({
        "firstName": firstName,
        "lastName": lastName,
        "dateOfBirth": dateOfBirth,
        "gender": gender,
        "profileCompleted": true,
        "updatedAt": ServerValue.timestamp,
      });
      
      print('Data to save: $userData');
      
      // Update the user data
      await userRef.update(userData);
      
      print('User details saved successfully to Firebase');
    } catch (e) {
      print('Error saving user details to Firebase: $e');
      print('Error stack trace: ${e is Error ? e.stackTrace : "Not available"}');
      throw e;
    }
  }

  /// Authenticates a user by phone number and password
  Future<Map<String, dynamic>?> authenticateUser(String phoneNumber, String password) async {
    try {
      print('Authenticating user with phone: $phoneNumber');
      
      // Hash the password
      final hashedPassword = _hashPassword(password);
      
      // In test mode, also check tempUsers
      if (kTestMode) {
        final String sanitizedPhone = _sanitizePhoneNumber(phoneNumber);
        final tempUserRef = _databaseRef.child('tempUsers/$sanitizedPhone');
        final tempUserSnapshot = await tempUserRef.once();
        
        if (tempUserSnapshot.snapshot.exists) {
          final tempUserData = tempUserSnapshot.snapshot.value as Map<dynamic, dynamic>;
          
          if (tempUserData['password'] == hashedPassword) {
            print('Temporary user authenticated successfully in test mode');
            
            // Save to shared preferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('phoneNumber', phoneNumber);
            await prefs.setString('tempUserId', sanitizedPhone);
            await prefs.setBool('isTemporary', true);
            await prefs.setBool('isLoggedIn', true);
            
            return {
              'userId': sanitizedPhone,
              'phoneNumber': phoneNumber,
              'isAuthenticated': true,
              'isTemporary': true,
              'userData': Map<String, dynamic>.from(tempUserData),
            };
          }
        }
      }
      
      // Regular authentication for real users
      final usersRef = _databaseRef.child('users');
      final usersQuery = await usersRef.orderByChild('phone').equalTo(phoneNumber).once();
      
      if (usersQuery.snapshot.exists) {
        final userData = usersQuery.snapshot.value as Map<dynamic, dynamic>;
        final userKey = userData.keys.first.toString();
        final userValue = userData[userKey] as Map<dynamic, dynamic>;
        
        if (userValue['password'] == hashedPassword) {
          print('User authenticated successfully');
          
          // Save to shared preferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('phoneNumber', phoneNumber);
          await prefs.setString('userId', userKey);
          await prefs.setBool('isTemporary', false);
          await prefs.setBool('isLoggedIn', true);
          
          return {
            'userId': userKey,
            'phoneNumber': phoneNumber,
            'isAuthenticated': true,
            'isTemporary': false,
            'userData': Map<String, dynamic>.from(userValue),
          };
        } else {
          print('Password does not match');
          return {'isAuthenticated': false, 'reason': 'invalid_password'};
        }
      }
      
      print('User not found');
      return {'isAuthenticated': false, 'reason': 'user_not_found'};
    } catch (e) {
      print('Error during authentication: $e');
      return {'isAuthenticated': false, 'reason': 'error', 'message': e.toString()};
    }
  }
  
  /// Create a new user with email authentication
  Future<Map<String, dynamic>> createEmailUser(String email, String password, String phoneNumber) async {
    try {
      // Create user with email/password in Firebase Auth
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final User? user = userCredential.user;
      
      if (user == null) {
        return {
          'success': false,
          'message': 'Failed to create user account',
        };
      }
      
      // Hash the password for storage
      final String hashedPassword = _hashPassword(password);
      
      // Create a reference to the user's data node
      final String userId = user.uid;
      DatabaseReference userRef = _databaseRef.child('users/$userId');
      
      // Save user data to the database
      await userRef.set({
        "email": email,
        "phone": phoneNumber,
        "password": hashedPassword, // Store hashed password
        "createdAt": ServerValue.timestamp,
        "uid": userId,
        "isTemporary": false,
        "profileCompleted": false,
      });
      
      return {
        'success': true,
        'userId': userId,
        'message': 'User created successfully',
      };
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      return {
        'success': false,
        'code': e.code,
        'message': e.message ?? 'An error occurred during sign up',
      };
    } catch (e) {
      print('Error creating user: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }
} 