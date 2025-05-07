import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';

enum ImageType { front, left, right }

class NoseUploadPage extends StatefulWidget {
  const NoseUploadPage({Key? key}) : super(key: key);
  @override State<NoseUploadPage> createState() => _NoseUploadPageState();
}

class _NoseUploadPageState extends State<NoseUploadPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final StorageService _storage = StorageService();
  final ImagePicker _picker = ImagePicker();

  File? _frontImage, _leftImage, _rightImage;
  String? _frontUrl, _leftUrl, _rightUrl;
  bool _loadingFront=false, _loadingLeft=false, _loadingRight=false;
  bool _savingAll=false;

  @override
  void initState() {
    super.initState();
    print('NoseUploadPage initialized');
    print('Current session: ${_supabase.auth.currentSession}');
    _loadExistingImages();
  }

  Future<void> _loadExistingImages() async {
    print('Loading existing images...');
    final user = _supabase.auth.currentSession?.user;
    if (user == null) {
      print('No user session found in _loadExistingImages');
      return;
    }
    print('User ID: ${user.id}');
    try {
      final data = await _supabase
        .from('simulation_requests')
        .select('front_image_url, left_image_url, right_image_url')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
        
      print('Retrieved simulation request data: $data');
      if (data != null) {
        setState(() {
          _frontUrl = data['front_image_url'];
          _leftUrl = data['left_image_url'];
          _rightUrl = data['right_image_url'];
        });
      }
      print('Loaded URLs - Front: $_frontUrl, Left: $_leftUrl, Right: $_rightUrl');
    } catch (e) {
      print('Error loading existing images: $e');
    }
  }

  Future<void> _pickImage(ImageSource src, ImageType type) async {
    final XFile? file = await _picker.pickImage(source: src);
    if (file == null) return;
    
    setState(() {
      switch (type) {
        case ImageType.front: _frontImage = File(file.path); break;
        case ImageType.left:  _leftImage  = File(file.path); break;
        case ImageType.right: _rightImage = File(file.path); break;
      }
    });
    await _uploadTemp(File(file.path), type);
  }

  Future<void> _uploadTemp(File file, ImageType type) async {
    print('Starting temporary upload for ${type.name} image');
    final user = _supabase.auth.currentSession?.user;
    if (user == null) {
      print('No user session found in _uploadTemp');
      return;
    }
    print('User ID for temp upload: ${user.id}');
    
    setState(() {
      if (type==ImageType.front) _loadingFront=true;
      if (type==ImageType.left)  _loadingLeft=true;
      if (type==ImageType.right) _loadingRight=true;
    });

    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final name = '${type.name}_$ts.jpg';
      final path = '${user.id}/$name';
      print('Uploading to path: $path to nose_temp bucket');
      final url = await _storage.uploadFile(file, path, bucket: 'nose_temp');
      print('Temporary upload successful. URL: $url');
      
      setState(() {
        if (type==ImageType.front) { _frontUrl=url; _loadingFront=false; }
        if (type==ImageType.left)  { _leftUrl =url; _loadingLeft=false;  }
        if (type==ImageType.right) { _rightUrl=url; _loadingRight=false; }
      });
    } catch (e) {
      print('Error in temporary upload: $e');
      setState(() {
        if (type==ImageType.front) _loadingFront=false;
        if (type==ImageType.left)  _loadingLeft=false;
        if (type==ImageType.right) _loadingRight=false;
      });
    }
  }

  Future<void> _saveAll() async {
    print('Save All Images button pressed');
    final user = _supabase.auth.currentSession?.user;
    if (user==null) {
      print('Error: No user session found');
      _showError('Please log in to save images');
      return;
    }

    if (_frontImage==null || _leftImage==null || _rightImage==null) {
      print('Error: Missing images - Front: ${_frontImage != null}, Left: ${_leftImage != null}, Right: ${_rightImage != null}');
      _showError('Please select all three images');
      return;
    }

    setState(() => _savingAll=true);
    print('Starting to save images...');
    print('User ID: ${user.id}');
    try {
      // Save to permanent storage in clinicbucket
      final frontPath = '${user.id}/front.jpg';
      final leftPath  = '${user.id}/left.jpg';
      final rightPath = '${user.id}/right.jpg';
      
      print('Uploading front image...');
      final frontUrl = await _storage.uploadFile(_frontImage!, frontPath, bucket: 'clinicbucket');
      print('Front image uploaded successfully: $frontUrl');
      
      print('Uploading left image...');
      final leftUrl  = await _storage.uploadFile(_leftImage!, leftPath, bucket: 'clinicbucket');
      print('Left image uploaded successfully: $leftUrl');
      
      print('Uploading right image...');
      final rightUrl = await _storage.uploadFile(_rightImage!, rightPath, bucket: 'clinicbucket');
      print('Right image uploaded successfully: $rightUrl');
      
      print('Creating simulation request record...');
      // Create simulation request record
      await _supabase.from('simulation_requests').insert({
        'user_id': user.id,
        'front_image_url': frontUrl,
        'left_image_url': leftUrl,
        'right_image_url': rightUrl,
        'status': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String()
      });
      print('Simulation request created successfully');
      
      print('Cleaning up temporary files...');
      // Clean up temporary files
      if (_frontUrl != null) {
        await _storage.deleteFile('${user.id}/front.jpg', bucket: 'nose_temp');
        print('Temporary front image deleted');
      }
      if (_leftUrl != null) {
        await _storage.deleteFile('${user.id}/left.jpg', bucket: 'nose_temp');
        print('Temporary left image deleted');
      }
      if (_rightUrl != null) {
        await _storage.deleteFile('${user.id}/right.jpg', bucket: 'nose_temp');
        print('Temporary right image deleted');
      }
      
      setState(() => _savingAll=false);
      print('All images saved successfully!');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Simulation request created successfully!')));
      Navigator.pop(context);
    } catch (e) {
      print('Error saving images: $e');
      setState(() => _savingAll=false);
      _showError('Failed to save images: ${e.toString()}');
    }
  }

  void _showError(String msg) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Error'), content: Text(msg),
      actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: const Text('OK'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Nose Photos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Text(
                'Welcome! You can upload front, left, and right profile images of your nose so our doctors can inspect them and provide personalized feedback.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Grid layout for image uploads
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1,
              children: [
                _buildUploadBox('Front View', _frontImage, _frontUrl, _loadingFront, () => _showModal(ImageType.front)),
                _buildUploadBox('Left Profile', _leftImage, _leftUrl, _loadingLeft, () => _showModal(ImageType.left)),
                _buildUploadBox('Right Profile', _rightImage, _rightUrl, _loadingRight, () => _showModal(ImageType.right)),
              ],
            ),
            
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                onPressed: _savingAll ? null : _saveAll,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: _savingAll 
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save All Images'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadBox(String label, File? localImage, String? url, bool loading, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 140,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: loading
              ? const Center(child: CircularProgressIndicator())
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: localImage != null
                    ? Image.file(localImage, fit: BoxFit.cover, width: double.infinity)
                    : url != null
                      ? Image.network(url, fit: BoxFit.cover, width: double.infinity)
                      : const Center(
                          child: Icon(Icons.add_a_photo, color: Colors.grey, size: 32),
                        ),
                ),
          ),
        ),
      ],
    );
  }

  void _showModal(ImageType type) => showModalBottomSheet(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Take Photo'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera, type);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery, type);
            },
          ),
        ],
      ),
    ),
  );
} 