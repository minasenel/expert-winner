import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  final String _defaultBucketName = 'clinicbucket';
  
  // Store the last signed URLs and their expiration times
  final Map<String, _SignedUrlData> _signedUrlCache = {};

  Future<String> uploadFile(File file, String filePath, {String? bucket}) async {
    try {
      final String bucketName = bucket ?? _defaultBucketName;
      
      await _supabaseClient.storage
          .from(bucketName)
          .upload(filePath, file);
      
      // Get a signed URL that lasts for 30 days
      return await getSignedUrl(filePath, durationInDays: 30);
    } catch (e) {
      throw Exception('Error uploading file: $e');
    }
  }

  Future<void> deleteFile(String filePath, {String? bucket}) async {
    try {
      final String bucketName = bucket ?? _defaultBucketName;
      
      await _supabaseClient.storage
          .from(bucketName)
          .remove([filePath]);
      
      // Remove from cache if exists
      _signedUrlCache.remove(filePath);
    } catch (e) {
      throw Exception('Error deleting file: $e');
    }
  }

  Future<String> getFileUrl(String filePath, {String? bucket}) async {
    try {
      // Check if we have a valid cached URL
      if (_signedUrlCache.containsKey(filePath)) {
        final cachedData = _signedUrlCache[filePath]!;
        if (!cachedData.isExpired) {
          return cachedData.url;
        }
      }
      
      // If no valid cached URL, get a new one
      return await getSignedUrl(filePath, durationInDays: 30);
    } catch (e) {
      throw Exception('Error getting file URL: $e');
    }
  }

  Future<String> getSignedUrl(String path, {int durationInDays = 30}) async {
    try {
      // Check cache first
      if (_signedUrlCache.containsKey(path)) {
        final cachedData = _signedUrlCache[path]!;
        if (!cachedData.isExpired) {
          return cachedData.url;
        }
      }

      // Convert days to seconds for Supabase API
      final durationInSeconds = durationInDays * 24 * 60 * 60;

      // Get new signed URL
      final response = await _supabaseClient
          .storage
          .from(_defaultBucketName)
          .createSignedUrl(path, durationInSeconds);
      
      // Cache the new URL
      _signedUrlCache[path] = _SignedUrlData(
        url: response,
        expirationTime: DateTime.now().add(Duration(days: durationInDays)),
      );
      
      return response;
    } catch (e) {
      print('Error getting signed URL: $e');
      rethrow;
    }
  }

  Future<String> getPublicUrl(String path) async {
    try {
      return _supabaseClient
          .storage
          .from(_defaultBucketName)
          .getPublicUrl(path);
    } catch (e) {
      print('Error getting public URL: $e');
      rethrow;
    }
  }

  // Method to refresh all expired URLs
  Future<void> refreshExpiredUrls() async {
    final expiredPaths = _signedUrlCache.entries
        .where((entry) => entry.value.isExpired)
        .map((entry) => entry.key)
        .toList();

    for (final path in expiredPaths) {
      await getSignedUrl(path, durationInDays: 30);
    }
  }
}

// Helper class to store signed URL data
class _SignedUrlData {
  final String url;
  final DateTime expirationTime;

  _SignedUrlData({
    required this.url,
    required this.expirationTime,
  });

  bool get isExpired => DateTime.now().isAfter(expirationTime);
} 