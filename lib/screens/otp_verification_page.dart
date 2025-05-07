import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import 'home_page.dart';
import 'user_details_page.dart';

class OTPVerificationPage extends StatefulWidget {
  final String phoneNumber;
  final bool isLogin;

  const OTPVerificationPage({
    super.key,
    required this.phoneNumber,
    this.isLogin = false,
  });

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final TextEditingController _pinController = TextEditingController();
  final SupabaseClient _supabase = Supabase.instance.client;
  Timer? _timer;
  int _timeLeft = 120; // 2 minutes in seconds
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  String _detailedErrorInfo = '';

  @override
  void initState() {
    super.initState();
    
    print('OTP Verification Page initialized');
    print('Phone number: ${widget.phoneNumber}');
    print('Is Login: ${widget.isLogin}');
    
    startTimer();
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

    print('Attempting to verify OTP: $otp');

    try {
      // Verify phone OTP
      final response = await _supabase.auth.verifyOTP(
        phone: widget.phoneNumber,
        token: otp,
        type: OtpType.sms,
      );

      if (response.user != null) {
        if (widget.isLogin) {
          // For login, go directly to home page
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          }
        } else {
          // For signup, go to user details page
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserDetailsPage(
                  phoneNumber: widget.phoneNumber,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error during OTP verification: $e');
      String errorMsg = 'Invalid verification code';
      
      if (e.toString().contains('invalid_otp')) {
        errorMsg = 'The verification code you entered is invalid. Please check and try again.';
      } else if (e.toString().contains('expired')) {
        errorMsg = 'The verification session has expired. Please request a new code.';
      }
      
      _showError(errorMsg);
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      setState(() {
        _isVerifying = false;
        _errorMessage = message;
        _detailedErrorInfo = message;
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
      _pinController.clear();
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

  Future<void> _resendCode() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    print('Attempting to resend code to ${widget.phoneNumber}');
    
    try {
      // Resend OTP using Supabase
      await _supabase.auth.signInWithOtp(
        phone: widget.phoneNumber,
      );
      
      // Reset the timer
      startTimer();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error resending OTP: $e');
      if (mounted) {
        setState(() {
          _detailedErrorInfo = e.toString();
        });
        _showError('Failed to resend verification code. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
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
        title: Text(
          widget.isLogin ? 'Log In' : 'Sign Up',
          style: const TextStyle(
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