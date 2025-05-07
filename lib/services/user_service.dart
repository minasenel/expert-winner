import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  /// Sanitize phone number for use as a key in database
  String _sanitizePhoneNumber(String phoneNumber) {
    // Remove non-alphanumeric characters for database key safety
    return phoneNumber.replaceAll(RegExp(r'[^\w]'), '');
  }
  
  /// Save user data to Supabase
  Future<void> saveUserData(String phoneNumber) async {
    try {
      final Session? session = _supabase.auth.currentSession;
      print('Current user: ${session?.user.id ?? "none"}');
      print('Phone number to save: $phoneNumber');
      
      // Check if we have an authenticated user
      if (session == null) {
        throw Exception('No authenticated user found. Please sign in first.');
      }
      
      // For authenticated users, save to regular users path
      final String userId = session.user.id;
      
      print('Saving user data for authenticated user ID: $userId');
      
      Map<String, dynamic> userData = {
        "id": userId,
        "phone": phoneNumber,
        "created_at": DateTime.now().toIso8601String(),
        "is_temporary": false
      };
      
      print('Data to save: $userData');
      
      // Set the user data
      await _supabase.from('users').upsert(userData);
      
      // Save phone number in SharedPreferences for easier access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('phoneNumber', phoneNumber);
      await prefs.setString('userId', userId);
      await prefs.setBool('isTemporary', false);
      
      print('User data saved successfully to Supabase');
    } catch (e) {
      print('Error saving user data to Supabase: $e');
      print('Error stack trace: ${e is Error ? e.stackTrace : "Not available"}');
      throw e;
    }
  }
  
  /// Get user phone number from Supabase or SharedPreferences
  Future<String?> getUserPhoneNumber() async {
    try {
      // First try to get from SharedPreferences for faster access
      final prefs = await SharedPreferences.getInstance();
      final cachedPhone = prefs.getString('phoneNumber');
      
      if (cachedPhone != null && cachedPhone.isNotEmpty) {
        return cachedPhone;
      }
      
      // If not in SharedPreferences, try to get from Supabase
      final Session? session = _supabase.auth.currentSession;
      
      // Check if we have an authenticated user
      if (session == null) {
        return null;
      }
      
      final String userId = session.user.id;
      
      // Get user data from Supabase
      final response = await _supabase
          .from('users')
          .select('phone')
          .eq('id', userId)
          .single();
      
      if (response != null) {
        final phoneNumber = response['phone'] as String?;
        
        // Cache it for future use
        if (phoneNumber != null) {
          await prefs.setString('phoneNumber', phoneNumber);
        }
        
        return phoneNumber;
      }
      
      return null;
    } catch (e) {
      print('Error getting user phone number: $e');
      return null;
    }
  }
  
  /// Save user personal details to Supabase
  Future<void> saveUserDetails(
    String firstName,
    String lastName,
    String dateOfBirth,
    String gender,
    String phoneNumber,
  ) async {
    try {
      print('Saving user details: $firstName, $lastName, $dateOfBirth, $gender');
      print('Phone Number: $phoneNumber');

      // Get the current session
      final Session? session = _supabase.auth.currentSession;

      // Check if we have an authenticated user
      if (session == null) {
        throw Exception('No authenticated user found');
      }

      // Prepare user data
      Map<String, dynamic> userData = {
        'user_id': session.user.id,
        'phone': phoneNumber,
        'first_name': firstName,
        'last_name': lastName,
        'date_of_birth': dateOfBirth,
        'gender': gender,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Save to users table
      await _supabase.from('users').upsert(userData);

      print('User details saved successfully');
    } catch (e) {
      print('Error in saveUserDetails: $e');
      rethrow;
    }
  }
} 