import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'create_password_page.dart';

// Same test mode flag as in main.dart and phone_input_page.dart
const bool _kTestMode = true;
// Default verification code for testing - only used in test mode
const String _kTestVerificationCode = '123456';
// Default verification ID for testing from phone_input_page.dart
const String _kTestVerificationId = 'test-verification-id';

class OTPVerificationPage extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;
  final String? testVerificationCode;

  const OTPVerificationPage({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
    this.testVerificationCode,
  });

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final TextEditingController _pinController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _timer;
  int _timeLeft = 120; // 2 minutes in seconds
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    print('OTP Verification Page initialized');
    print('Phone number: ${widget.phoneNumber}');
    print('Verification ID: ${widget.verificationId}');
    print('Resend token available: ${widget.resendToken != null}');
    
    // If in test mode, auto-fill the verification code
    if (widget.testVerificationCode != null) {
      print('Using test verification code: ${widget.testVerificationCode}');
      _pinController.text = widget.testVerificationCode!;
      
      // Optional: Auto-verify after a short delay
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          print('Auto-verifying with test code');
          _verifyOTP(_pinController.text);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void startTimer() {
    _timer?.cancel();
    setState(() {
      _timeLeft = 120;
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOTP(String otp) async {
    if (otp.length != 6) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    print('Attempting to verify OTP: $otp with verificationId: ${widget.verificationId}');
    print('Test mode enabled: $_kTestMode');

    try {
      // Special handling for test mode
      if (_kTestMode && widget.verificationId == _kTestVerificationId) {
        print('TEST MODE: Bypassing actual OTP verification');
        await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
        
        if (mounted) {
          setState(() {
            _isVerifying = false;
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test mode: Phone number verified successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Navigate to Create Password page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePasswordPage(
                phoneNumber: widget.phoneNumber,
              ),
            ),
          );
        }
        return;
      }
      
      // Normal verification process for production
      // Check if verification ID is valid
      if (widget.verificationId.isEmpty) {
        throw Exception('Verification ID is empty. Try requesting a new code.');
      }
      
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      print('Created phone auth credential, attempting to sign in...');

      // Sign in with the credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      print('Sign in successful, user UID: ${user?.uid}');

      if (mounted) {
        setState(() {
          _isVerifying = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone number verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to Create Password page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreatePasswordPage(
              phoneNumber: widget.phoneNumber,
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error during OTP verification: ${e.code} - ${e.message}');
      String errorMsg = 'Invalid verification code';
      
      switch (e.code) {
        case 'invalid-verification-code':
          errorMsg = 'The verification code you entered is invalid. Please check and try again.';
          break;
        case 'session-expired':
          errorMsg = 'The verification session has expired. Please request a new code.';
          break;
        default:
          errorMsg = e.message ?? 'An error occurred during verification';
          break;
      }
      
      _showError(errorMsg);
    } catch (e) {
      print('General error during OTP verification: $e');
      print('Stack trace: ${StackTrace.current}');
      _showError('Error: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _isVerifying = false;
        _errorMessage = message;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
      _pinController.clear();
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    print('Attempting to resend code to ${widget.phoneNumber} with token: ${widget.resendToken}');

    try {
      // In test mode, just simulate resending
      if (_kTestMode) {
        print('TEST MODE: Simulating code resend');
        await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
        
        if (mounted) {
          setState(() {
            _isResending = false;
          });
          
          startTimer();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test mode: Verification code resent'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }
      
      // Normal resend process for production
      await _auth.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: widget.resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed (on Android)
          print('Auto verification completed on resend');
          try {
            await _auth.signInWithCredential(credential);
            
            if (mounted) {
              setState(() {
                _isResending = false;
              });
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreatePasswordPage(
                    phoneNumber: widget.phoneNumber,
                  ),
                ),
              );
            }
          } catch (e) {
            print('Error in auto verification during resend: $e');
            _showError('Automatic verification failed: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed during resend: ${e.code} - ${e.message}');
          
          String errorMsg = 'Failed to resend verification code';
          
          switch (e.code) {
            case 'too-many-requests':
              errorMsg = 'Too many attempts. Please try again later.';
              break;
            case 'invalid-phone-number':
              errorMsg = 'The phone number format is invalid.';
              break;
            default:
              errorMsg = e.message ?? 'An unknown error occurred';
              break;
          }
          
          _showError(errorMsg);
        },
        codeSent: (String verificationId, int? resendToken) {
          print('Code resent successfully. New verification ID: $verificationId');
          
          if (mounted) {
            setState(() {
              _isResending = false;
            });
            startTimer();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Verification code resent'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Code auto retrieval timed out during resend: $verificationId');
          
          if (mounted && _isResending) {
            setState(() {
              _isResending = false;
            });
            _showError('SMS code auto-retrieval timed out. Please try again.');
          }
        },
      );
    } catch (e) {
      print('General error during resend: $e');
      _showError('Failed to resend code: ${e.toString()}');
    }
  }

  String formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Verify Phone',
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter verification code',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C2C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Code sent to ${widget.phoneNumber}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF8E8D8A),
                ),
              ),
              if (_kTestMode)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Test mode is enabled. Using sample verification code.',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              Center(
                child: Pinput(
                  length: 6,
                  controller: _pinController,
                  onCompleted: _verifyOTP,
                  enabled: !_isVerifying,
                  defaultPinTheme: PinTheme(
                    width: 56,
                    height: 56,
                    textStyle: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF8E8D8A)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
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
                ),
              if (_isVerifying)
                const Center(
                  child: CircularProgressIndicator(),
                )
              else
                Center(
                  child: _timeLeft > 0
                      ? Text(
                          'Time remaining: ${formatTime(_timeLeft)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF8E8D8A),
                          ),
                        )
                      : TextButton(
                          onPressed: _isResending ? null : _resendCode,
                          child: _isResending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Resend Code',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF8E8D8A),
                                  ),
                                ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 