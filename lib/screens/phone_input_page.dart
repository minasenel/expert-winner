import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'otp_verification_page.dart';
import 'create_password_page.dart';
import 'package:flutter/foundation.dart';

// Import the test mode constant
import '../main.dart' show kTestModeEnabled;
import '../services/user_service.dart' show kTestMode;

// These values are used in test mode
const String _kTestPhoneNumber = '+905551234567'; // Turkish phone number format
const String _kTestVerificationCode = '123456';

class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  @override
  State<PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _showDetailedError = false;
  String _detailedErrorInfo = '';
  String? _verificationId;
  int? _resendToken;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    
    // For testing - pre-fill the phone number in test mode
    if (kTestMode) {
      _phoneController.text = _kTestPhoneNumber;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _verifyPhoneNumber() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        // In test mode, bypass actual phone verification
        if (kTestMode) {
          print('Test mode: Bypassing phone verification for development');
          
          // Wait briefly to simulate network
          await Future.delayed(const Duration(milliseconds: 800));
          
          // Go directly to password creation in test mode
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreatePasswordPage(
                  phoneNumber: _phoneController.text,
                ),
              ),
            );
            
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
        
        // Only reach here if not in test mode - proceed with normal verification
        await _auth.verifyPhoneNumber(
          phoneNumber: _phoneController.text,
          verificationCompleted: (PhoneAuthCredential credential) {
            print("Auto verification completed with credential: $credential");
            _handleVerificationCompleted(credential);
          },
          verificationFailed: (FirebaseAuthException e) {
            print("FIREBASE AUTH ERROR: $e");
            print("ERROR CODE: ${e.code}");
            print("ERROR MESSAGE: ${e.message}");
            print("STACK TRACE: ${StackTrace.current}");
            
            setState(() {
              _isLoading = false;
              _errorMessage = "Verification failed: ${e.message}";
            });
          },
          codeSent: (String verificationId, int? resendToken) {
            print("SMS code sent to ${_phoneController.text}, verification ID: $verificationId");
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OTPVerificationPage(
                  phoneNumber: _phoneController.text,
                  verificationId: verificationId,
                  resendToken: resendToken,
                  testVerificationCode: kTestMode ? _kTestVerificationCode : null,
                ),
              ),
            );
            setState(() {
              _isLoading = false;
            });
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            print("Code auto retrieval timeout for verification ID: $verificationId");
          },
          // Increase timeout for better user experience
          timeout: const Duration(seconds: 120),
        );
      } catch (e) {
        print("Unexpected error during phone verification: $e");
        setState(() {
          _isLoading = false;
          _errorMessage = "An unexpected error occurred. Please try again.";
        });
      }
    }
  }
  
  void _handleVerificationCompleted(PhoneAuthCredential credential) async {
    print("Auto verification completed for ${_phoneController.text}");
    
    try {
      // Sign in with the credential
      await _auth.signInWithCredential(credential);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone verified automatically')),
        );
        
        // Navigate to next screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CreatePasswordPage(
              phoneNumber: _phoneController.text,
            ),
          ),
        );
      }
    } catch (e) {
      print("Error in auto verification: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Automatic verification failed: $e";
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _isLoading = false;
        _showDetailedError = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Details',
            textColor: Colors.white,
            onPressed: () {
              _showErrorDialog();
            },
          ),
        ),
      );
    }
  }
  
  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error Details'),
        content: SingleChildScrollView(
          child: Text(_detailedErrorInfo),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _detailedErrorInfo));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
              Navigator.of(context).pop();
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your phone number',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C2C2C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "We'll send you a verification code",
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF4A4A4A),
                    ),
                  ),
                  if (kTestMode)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Test mode is enabled. Using code: $_kTestVerificationCode',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '+1 234 567 8900',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      if (!value.startsWith('+')) {
                        return 'Phone number must start with country code (e.g., +1)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                          if (_showDetailedError) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _showErrorDialog,
                              child: const Text('Show Error Details'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                backgroundColor: Colors.red.shade100,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyPhoneNumber,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E8D8A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
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
} 