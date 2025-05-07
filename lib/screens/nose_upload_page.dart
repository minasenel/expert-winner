import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';

class NoseUploadPage extends StatefulWidget {
  const NoseUploadPage({Key? key}) : super(key: key);

  @override
  State<NoseUploadPage> createState() => _NoseUploadPageState();
}

class _NoseUploadPageState extends State<NoseUploadPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final ImagePicker _picker = ImagePicker();
  
  // Local image files
  File? _frontImage;
  File? _leftImage;
  File? _rightImage;
  
  // Temporary storage URLs before final save
  String? _frontImageUrl;
  String? _leftImageUrl;
  String? _rightImageUrl;
  
  // Loading states
  bool _uploadingFrontImage = false;
  bool _uploadingLeftImage = false;
  bool _uploadingRightImage = false;
  bool _savingAllImages = false;
  
  // Track which images have been selected
  bool _frontImageSelected = false;
  bool _leftImageSelected = false;
  bool _rightImageSelected = false;
  
  @override
  void initState() {
    super.initState();
    _loadExistingImages();
  }
  
  Future<void> _loadExistingImages() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return;
      
      final dataSnapshot = await _database
          .child('users/${user.uid}/nosePhotos')
          .get();
      
      if (dataSnapshot.exists) {
        final data = dataSnapshot.value as Map<dynamic, dynamic>?;
        if (data != null) {
          setState(() {
            _frontImageUrl = data['front'] as String?;
            _leftImageUrl = data['left'] as String?;
            _rightImageUrl = data['right'] as String?;
            
            // Mark images as selected if they exist
            _frontImageSelected = _frontImageUrl != null;
            _leftImageSelected = _leftImageUrl != null;
            _rightImageSelected = _rightImageUrl != null;
          });
        }
      }
    } catch (e) {
      print('Error loading existing images: $e');
    }
  }
  
  Future<void> _showImageSourceOptions(ImageType imageType) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose an option',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF2C2C2C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF8E8D8A),
                    child: Icon(Icons.camera_alt, color: Colors.white),
                  ),
                  title: const Text('Take a Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _getImage(ImageSource.camera, imageType);
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF8E8D8A),
                    child: Icon(Icons.photo_library, color: Colors.white),
                  ),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _getImage(ImageSource.gallery, imageType);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Future<void> _getImage(ImageSource source, ImageType imageType) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      
      if (pickedFile == null) return;
      
      final File imageFile = File(pickedFile.path);
      
      // Save the selected image file locally
      setState(() {
        switch (imageType) {
          case ImageType.front:
            _frontImage = imageFile;
            _frontImageSelected = true;
            break;
          case ImageType.left:
            _leftImage = imageFile;
            _leftImageSelected = true;
            break;
          case ImageType.right:
            _rightImage = imageFile;
            _rightImageSelected = true;
            break;
        }
      });
      
      // Generate a temporary URL by uploading the image to Firebase
      // This allows the user to see the uploaded image before final save
      await _getTempImageUrl(imageFile, imageType);
      
    } catch (e) {
      _showErrorDialog('Permission Denied', 'Please grant camera and storage permissions to use this feature.');
      print('Error picking image: $e');
    }
  }
  
  Future<void> _getTempImageUrl(File imageFile, ImageType imageType) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      _showErrorDialog('Authentication Error', 'Please sign in to upload images.');
      return;
    }
    
    try {
      // Set loading state
      setState(() {
        switch (imageType) {
          case ImageType.front:
            _uploadingFrontImage = true;
            break;
          case ImageType.left:
            _uploadingLeftImage = true;
            break;
          case ImageType.right:
            _uploadingRightImage = true;
            break;
        }
      });
      
      // Create a temporary path with a timestamp to avoid cache issues
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final String fileName = '${_getFileNameFromType(imageType)}_$timestamp.jpg';
      final String path = 'nose_images_temp/${user.uid}/$fileName';
      
      final Reference storageRef = _storage.ref().child(path);
      final UploadTask uploadTask = storageRef.putFile(imageFile);
      
      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      
      // Store the URL temporarily for display
      setState(() {
        switch (imageType) {
          case ImageType.front:
            _frontImageUrl = downloadUrl;
            _uploadingFrontImage = false;
            break;
          case ImageType.left:
            _leftImageUrl = downloadUrl;
            _uploadingLeftImage = false;
            break;
          case ImageType.right:
            _rightImageUrl = downloadUrl;
            _uploadingRightImage = false;
            break;
        }
      });
      
    } catch (e) {
      setState(() {
        switch (imageType) {
          case ImageType.front:
            _uploadingFrontImage = false;
            break;
          case ImageType.left:
            _uploadingLeftImage = false;
            break;
          case ImageType.right:
            _uploadingRightImage = false;
            break;
        }
      });
      
      _showErrorDialog('Upload Failed', 'There was an error uploading your image. Please try again.');
      print('Error uploading temporary image: $e');
    }
  }
  
  Future<void> _saveAllImagesToFirebase() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      _showErrorDialog('Authentication Error', 'Please sign in to save images.');
      return;
    }
    
    // Check if all three images are selected
    if (!_frontImageSelected || !_leftImageSelected || !_rightImageSelected) {
      _showErrorDialog('Missing Images', 'Please upload all three photos before saving.');
      return;
    }
    
    try {
      setState(() {
        _savingAllImages = true;
      });
      
      Map<String, String> imageUrls = {};
      
      // Upload front image
      if (_frontImage != null) {
        final frontPath = 'nose_images/${user.uid}/front.jpg';
        final frontStorageRef = _storage.ref().child(frontPath);
        await frontStorageRef.putFile(_frontImage!);
        imageUrls['front'] = await frontStorageRef.getDownloadURL();
      } else if (_frontImageUrl != null) {
        // Use existing URL if file wasn't changed
        imageUrls['front'] = _frontImageUrl!;
      }
      
      // Upload left image
      if (_leftImage != null) {
        final leftPath = 'nose_images/${user.uid}/left.jpg';
        final leftStorageRef = _storage.ref().child(leftPath);
        await leftStorageRef.putFile(_leftImage!);
        imageUrls['left'] = await leftStorageRef.getDownloadURL();
      } else if (_leftImageUrl != null) {
        // Use existing URL if file wasn't changed
        imageUrls['left'] = _leftImageUrl!;
      }
      
      // Upload right image
      if (_rightImage != null) {
        final rightPath = 'nose_images/${user.uid}/right.jpg';
        final rightStorageRef = _storage.ref().child(rightPath);
        await rightStorageRef.putFile(_rightImage!);
        imageUrls['right'] = await rightStorageRef.getDownloadURL();
      } else if (_rightImageUrl != null) {
        // Use existing URL if file wasn't changed
        imageUrls['right'] = _rightImageUrl!;
      }
      
      // Save all URLs to Firebase Realtime Database
      await _database
          .child('users/${user.uid}/nosePhotos')
          .update(imageUrls);
      
      setState(() {
        _savingAllImages = false;
        // Update URLs with permanent ones
        _frontImageUrl = imageUrls['front'];
        _leftImageUrl = imageUrls['left'];
        _rightImageUrl = imageUrls['right'];
      });
      
      _showSuccessSnackbar('All images saved successfully!');
    } catch (e) {
      setState(() {
        _savingAllImages = false;
      });
      
      _showErrorDialog('Save Failed', 'There was an error saving your images. Please try again.');
      print('Error saving all images: $e');
    }
  }
  
  String _getFileNameFromType(ImageType type) {
    switch (type) {
      case ImageType.front:
        return 'front';
      case ImageType.left:
        return 'left';
      case ImageType.right:
        return 'right';
    }
  }
  
  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8E8D8A),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nose Simulation',
          style: TextStyle(
            color: Color(0xFF2C2C2C),
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C2C2C)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5F5F5),
              Color(0xFFE8E6E1),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload Photos for Nose Simulation',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C2C2C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please upload clear, well-lit photos of your face from the front and both sides.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4A4A4A),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Front Profile Photo Section
                  _buildPhotoSection(
                    title: 'Front Photo',
                    buttonText: 'Take or Upload Front Photo',
                    image: _frontImage,
                    imageUrl: _frontImageUrl,
                    isUploading: _uploadingFrontImage,
                    onPressed: () => _showImageSourceOptions(ImageType.front),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Left Side Profile Photo Section
                  _buildPhotoSection(
                    title: 'Left Side Photo',
                    buttonText: 'Take or Upload Left Photo',
                    image: _leftImage,
                    imageUrl: _leftImageUrl,
                    isUploading: _uploadingLeftImage,
                    onPressed: () => _showImageSourceOptions(ImageType.left),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Right Side Profile Photo Section
                  _buildPhotoSection(
                    title: 'Right Side Photo',
                    buttonText: 'Take or Upload Right Photo',
                    image: _rightImage,
                    imageUrl: _rightImageUrl,
                    isUploading: _uploadingRightImage,
                    onPressed: () => _showImageSourceOptions(ImageType.right),
                  ),
                  
                  const SizedBox(height: 36),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _savingAllImages || 
                                 _uploadingFrontImage || 
                                 _uploadingLeftImage || 
                                 _uploadingRightImage || 
                                 !_allImagesSelected() 
                                 ? null 
                                 : _saveAllImagesToFirebase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E8D8A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _savingAllImages
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Text(
                                  'Saving Images...',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'SAVE ALL IMAGES',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
  
  bool _allImagesSelected() {
    return _frontImageSelected && _leftImageSelected && _rightImageSelected;
  }
  
  Widget _buildPhotoSection({
    required String title,
    required String buttonText,
    required File? image,
    required String? imageUrl,
    required bool isUploading,
    required VoidCallback onPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C2C2C),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 220,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: isUploading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF8E8D8A),
                    ),
                  )
                : image != null
                    ? Image.file(
                        image,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  color: const Color(0xFF8E8D8A),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 48,
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_a_photo,
                                  color: Color(0xFF8E8D8A),
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No photo selected',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isUploading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8E8D8A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              buttonText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Enum to identify which image type is being processed
enum ImageType {
  front,
  left,
  right,
} 