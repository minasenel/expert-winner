import 'package:flutter/material.dart';

class OurTeamPage extends StatefulWidget {
  const OurTeamPage({Key? key}) : super(key: key);

  @override
  State<OurTeamPage> createState() => _OurTeamPageState();
}

class _OurTeamPageState extends State<OurTeamPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Our Team',
          style: TextStyle(
            color: Color(0xFF4E342E),
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4E342E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF7EF),  // Light sand at top
              Color(0xFFF6DCBD),  // Main sand in middle
              Color(0xFFEAC8A2),  // Deeper sand at bottom
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome to our clinic.',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4E342E),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'We are an internationally trusted aesthetic clinic specializing in personalized, high-quality care. Our mission is to help clients from around the world feel confident and empowered through expert aesthetic solutions.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Color(0xFF4E342E),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'This app was built to streamline your journey — from uploading your profile photos to visualizing potential results — all in one place. Whether you\'re just exploring or ready to take the next step, we\'re here to guide you.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Color(0xFF4E342E),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Our team consists of licensed, experienced doctors who work with precision, transparency, and care. We uphold the highest ethical standards and respect every individual\'s unique goals and concerns. Your safety, comfort, and satisfaction are our top priorities.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Color(0xFF4E342E),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Thank you for choosing us.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Color(0xFF4E342E),
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
  }
} 