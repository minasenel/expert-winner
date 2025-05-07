import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'nose_upload_page.dart';

class AnimatedServiceButton extends StatefulWidget {
  final String title;
  final VoidCallback onPressed;
  final Color color;
  final String? imageUrl;

  const AnimatedServiceButton({
    Key? key,
    required this.title,
    required this.onPressed,
    required this.color,
    this.imageUrl,
  }) : super(key: key);

  @override
  State<AnimatedServiceButton> createState() => _AnimatedServiceButtonState();
}

class _AnimatedServiceButtonState extends State<AnimatedServiceButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                image: widget.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(widget.imageUrl!),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.40),
                          BlendMode.darken,
                        ),
                      )
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    splashColor: Colors.white.withOpacity(0.2),
                    highlightColor: Colors.transparent,
                    onTap: () {}, // Actual tap is handled by GestureDetector
                    child: Container(
                      padding: const EdgeInsets.all(0),
                      alignment: Alignment.center,
                      child: widget.imageUrl != null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Spacer(),
                              // Text container with gradient background at the bottom
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.5),
                                    ],
                                  ),
                                ),
                                child: Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 3.0,
                                        color: Colors.black,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getIconForTitle(widget.title),
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  IconData _getIconForTitle(String title) {
    switch (title) {
      case 'Nose Simulation':
        return Icons.face;
      case 'Ask Our Assistant':
        return Icons.chat;
      case 'Our Team':
        return Icons.people;
      default:
        return Icons.spa;
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  String? _phoneNumber;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get phone number from UserService
      final phoneNumber = await _userService.getUserPhoneNumber();
      
      setState(() {
        _phoneNumber = phoneNumber;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      // Sign out from Firebase
      await _auth.signOut();
      
      // Clear SharedPreferences data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Removes all data
      
      print('User signed out and preferences cleared');
      
      // Navigate to welcome page
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
      }
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Serenity Spa',
          style: TextStyle(
            color: Color(0xFF2C2C2C),
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF2C2C2C)),
            onPressed: _signOut,
          ),
        ],
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Our Services',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C2C2C),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildServiceButton(
                              title: 'Nose Simulation',
                              onPressed: () {
                                print('Nose Simulation button clicked');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const NoseUploadPage(),
                                  ),
                                );
                              },
                              color: const Color(0xFF8E8D8A),
                              imageUrl: 'https://m001z3.s3.amazonaws.com/stock%20ph/istockphoto-1482627867-612x612.jpg',
                            ),
                            const SizedBox(height: 8), // Reduced spacing between buttons
                            _buildServiceButton(
                              title: 'Ask Our Assistant',
                              onPressed: () {
                                print('Ask Our Assistant button clicked');
                              },
                              color: const Color(0xFF8E8D8A).withOpacity(0.9),
                              imageUrl: 'https://m001z3.s3.amazonaws.com/stock%20ph/medicine-healthcare-people-concept-female-600nw-2188588635.webp',
                            ),
                            const SizedBox(height: 8), // Reduced spacing between buttons
                            _buildServiceButton(
                              title: 'Our Team',
                              onPressed: () {
                                print('Our Team button clicked');
                              },
                              color: const Color(0xFF8E8D8A).withOpacity(0.8),
                              imageUrl: 'https://m001z3.s3.amazonaws.com/stock%20ph/group-doctors-nurses-standing-join-600nw-1487355692.webp',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildServiceButton({
    required String title,
    required VoidCallback onPressed,
    required Color color,
    String? imageUrl,
  }) {
    // Calculate a good aspect ratio for the buttons based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Make buttons smaller so all 3 fit on screen without scrolling
    // Use approximately 25% of screen height for each button (3 buttons + spacing = ~85% of available space)
    final buttonHeight = (screenHeight - 150) / 3.5; // Account for app bar, title, and spacing
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0), // Reduce spacing between buttons
      child: SizedBox(
        width: double.infinity,
        height: buttonHeight,
        child: AnimatedServiceButton(
          title: title,
          onPressed: onPressed,
          color: color,
          imageUrl: imageUrl,
        ),
      ),
    );
  }
} 