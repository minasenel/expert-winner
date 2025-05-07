import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  final String _defaultBucketName = 'clinicbucket';

  Future<String> uploadFile(File file, String filePath, {String? bucket}) async {
    try {
      final String bucketName = bucket ?? _defaultBucketName;
      
      await _supabaseClient.storage
          .from(bucketName)
          .upload(filePath, file);
      
      final String publicUrl = _supabaseClient.storage
          .from(bucketName)
          .getPublicUrl(filePath);
      
      return publicUrl;
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
    } catch (e) {
      throw Exception('Error deleting file: $e');
    }
  }

  Future<String> getFileUrl(String filePath, {String? bucket}) async {
    try {
      final String bucketName = bucket ?? _defaultBucketName;
      
      return _supabaseClient.storage
          .from(bucketName)
          .getPublicUrl(filePath);
    } catch (e) {
      throw Exception('Error getting file URL: $e');
    }
  }
} 