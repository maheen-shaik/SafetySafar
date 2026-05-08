import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'utils/api_config.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final String countryCode;
  final String countryName;
  
  const OtpVerificationScreen({
    super.key, 
    required this.phoneNumber, 
    required this.verificationId,
    required this.countryCode,
    required this.countryName,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  
  Timer? _timer;
  int _secondsRemaining = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    String otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all 6 digits')),
      );
      return;
    }

    try {
      debugPrint('[OTP] Verifying OTP: $otp for phone: ${widget.phoneNumber}');
      
      final response = await http.post(
        Uri.parse(ApiConfig.verifyOtp),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': widget.phoneNumber,
          'otp': otp,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[OTP] Verification successful! Token: ${data['access_token']}');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP Verified Successfully!')),
        );
        Navigator.pop(context, data);
      } else {
        final error = jsonDecode(response.body)['detail'] ?? 'Invalid OTP';
        debugPrint('[OTP] Verification failed: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    } catch (e) {
       debugPrint('[OTP] Exception: $e');
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2C3E50), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              "Verify Phone",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF2C3E50)),
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                text: "We've sent a 6-digit verification code to ",
                style: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 15, height: 1.5),
                children: [
                  TextSpan(
                    text: "${widget.countryCode} ${widget.phoneNumber}",
                    style: const TextStyle(color: Color(0xFF0E3A7E), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Firebase Verification ID Active",
              style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 48),

            // OTP INPUT ROW
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) => _buildOtpBox(index)),
            ),

            const SizedBox(height: 40),

            // TIMER & RESEND
            Center(
              child: Column(
                children: [
                  Text(
                    _canResend ? "Didn't receive code?" : "Resend code in ",
                    style: const TextStyle(color: Color(0xFF7F8C8D)),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _canResend ? _startTimer : null,
                    child: Text(
                      _canResend ? "RESEND OTP" : "00:${_secondsRemaining.toString().padLeft(2, '0')}",
                      style: TextStyle(
                        color: _canResend ? const Color(0xFFFF7A00) : const Color(0xFF0E3A7E),
                        fontWeight: FontWeight.bold,
                        decoration: _canResend ? TextDecoration.underline : TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // VERIFY BUTTON
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E3A7E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  "Verify & Continue",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return Container(
      width: 48,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _controllers[index].text.isNotEmpty ? const Color(0xFFFF7A00) : const Color(0xFFDDE1E6),
          width: 1.5,
        ),
        boxShadow: _focusNodes[index].hasFocus
            ? [BoxShadow(color: const Color(0xFFFF7A00).withValues(alpha:0.1), blurRadius: 8, spreadRadius: 1)]
            : null,
      ),
      child: Center(
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          onChanged: (value) {
            if (value.isNotEmpty && index < 5) {
              _focusNodes[index + 1].requestFocus();
            } else if (value.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
            setState(() {});
          },
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
          decoration: const InputDecoration(
            counterText: "",
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
