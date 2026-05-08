import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'registration_screen.dart';
import 'otp_screen.dart';
import 'reset_password_screen.dart';
import 'screens/tourist_dashboard.dart';
import 'screens/authority_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'utils/country_codes.dart';
import 'utils/api_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isEmailSelected = true;
  bool _obscurePassword = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool isLoading = false;
  
  // Country selector
  late Country _selectedCountry;
  late List<String> _countryNames;

  // OTP Timer logic
  Timer? _timer;
  int _secondsRemaining = 60;
  bool _isTimerActive = false;

  void _startTimer() {
    setState(() {
      _secondsRemaining = 60;
      _isTimerActive = true;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() => _isTimerActive = false);
        timer.cancel();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedCountry = CountryCodes.getDefaultCountry();
    _countryNames = CountryCodes.getCountryNames();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _handleSendOTP() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your mobile number')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final phone = _phoneController.text.trim();
      final fullPhone = CountryCodes.formatPhoneNumber(phone, _selectedCountry.code);
      debugPrint('[OTP] Requesting OTP for phone: $fullPhone');
      
      final response = await http.post(
        Uri.parse(ApiConfig.sendOtp),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': fullPhone,
          'country': _selectedCountry.name,
          'country_code': _selectedCountry.code
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() => isLoading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('[OTP] Code sent successfully! OTP: ${data['otp']}');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent successfully!')),
        );

        _startTimer();

        // Navigate to OTP Screen
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              phoneNumber: phone,
              countryCode: _selectedCountry.code,
              countryName: _selectedCountry.name,
              verificationId: '', // Not used in backend OTP
            ),
          ),
        );

        if (result != null && result is Map && mounted) {
          final role = result['role'];
          if (role == null) {
            throw Exception("Role missing in OTP response");
          }
          final authToken = result['access_token'] ?? '';
          final userId = result['user_id'] ?? '';
          _navigateToDashboard(role, authToken, userId);
        }
      } else {
        final error = jsonDecode(response.body)['detail'] ?? 'Failed to send OTP';
        debugPrint('[OTP] Send failed: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    } catch (e) {
      debugPrint("🔥 OTP ERROR: $e");

      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _navigateToDashboard(String role, String authToken, String userId) {
  final normalizedRole = role.toLowerCase();

  if (normalizedRole == 'authority') {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AuthorityDashboard(
          authToken: authToken,
          userId: userId,
        ),
      ),
    );
  } else {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TouristDashboard(
          authToken: authToken,
          userId: userId,
        ),
      ),
    );
  }
}

  Future<void> _handleGoogleSignIn() async {
    setState(() => isLoading = true);
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw FirebaseAuthException(
          code: 'MISSING_GOOGLE_TOKEN',
          message: 'Google auth token missing. Check Firebase OAuth settings and SHA configuration.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      if (userCredential.user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Google Sign-In successful."),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        // For Google Sign-In, we'll need to implement backend integration later
        // For now, passing empty strings (should be implemented with proper backend call)
        _navigateToDashboard('tourist', '', userCredential.user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In failed: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ResetPasswordScreen()),
    );
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final url = Uri.parse(ApiConfig.login);
      debugPrint("Calling API: $url");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('Server not responding. Check your connection.');
      });

      debugPrint("STATUS CODE: ${response.statusCode}");
      debugPrint("RESPONSE BODY: ${response.body}");

      if (response.statusCode == 200) {
        try {
          debugPrint("RAW RESPONSE: ${response.body}");

          final data = jsonDecode(response.body);
          debugPrint("PARSED ROLE: ${data['role']}");

          final role = data['role']?.toString().toLowerCase();
          if (role == null) {
            throw Exception("Role missing in response: ${response.body}");
          }
          final String authToken = data['access_token'] ?? '';
          final String userId = data['user_id'] ?? '';

          debugPrint("✅ Login Success");
          debugPrint("Role: $role");

          if (mounted) {
            _navigateToDashboard(role, authToken, userId);
          }

        } catch (e) {
          debugPrint("❌ JSON ERROR: $e");
          debugPrint("❌ RAW BODY: ${response.body}");
         

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Parsing error: $e')),
            );
          }
        }

      } else {
        debugPrint("RAW ERROR BODY: ${response.body}");

        String errorMessage;

        try {
          final errorJson = jsonDecode(response.body);
          errorMessage = errorJson['detail'] ?? 'Login failed';
        } catch (e) {
          errorMessage = response.body;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }

    } catch (e) {
      debugPrint("🔥 REAL ERROR: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }

    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E3A7E),
      body: SafeArea(
        child: Column(
          children: [
            // 🔵 HEADER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.circle, color: Colors.orange, size: 8),
                        SizedBox(width: 8),
                        Text(
                          "Safety Safar",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Travel Safe.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const Text(
                    "Travel Smart.",
                    style: TextStyle(
                      color: Color(0xFFFF7A00),
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Smart Tourist Safety • Official Platform",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha:0.7),
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // ⚪ LOGIN CARD
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          "SIGN IN TO YOUR ACCOUNT",
                          style: TextStyle(
                            letterSpacing: 1.5,
                            color: Color(0xFF7F8C8D),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 🔘 TAB SWITCH
                      Container(
                        height: 54,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF1F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            _buildTabButton("Email", true),
                            _buildTabButton("Phone / OTP", false),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      isEmailSelected ? _buildEmailForm() : _buildPhoneForm(),

                      const SizedBox(height: 24),
                      
                      // Footer Branding
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildFooterItem(Icons.lock_rounded, "Encrypted"),
                            _buildFooterItem(Icons.qr_code_2_rounded, "Blockchain ID"),
                            _buildFooterItem(Icons.verified_user_rounded, "IN Govt. Secure"),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String text, bool isEmail) {
    bool selected = isEmailSelected == isEmail;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isEmailSelected = isEmail),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha:0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: selected ? const Color(0xFF2C3E50) : const Color(0xFF95A5A6),
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("EMAIL ADDRESS", style: labelStyle),
        const SizedBox(height: 10),
        _buildTextField(_emailController, "safira@tourist.in", Icons.alternate_email),
        const SizedBox(height: 24),
        const Text("PASSWORD", style: labelStyle),
        const SizedBox(height: 10),
        _buildTextField(
          _passwordController,
          "••••••••",
          Icons.lock_outline,
          obscure: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: const Color(0xFF95A5A6),
              size: 20,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _showForgotPasswordDialog,
            child: const Text(
              "Forgot password?",
              style: TextStyle(color: Color(0xFFFF7A00), fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildPrimaryButton("Sign In Securely", _handleLogin, icon: Icons.shield_rounded),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text("or", style: TextStyle(color: Colors.grey)),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        const SizedBox(height: 24),
        _buildOutlineButton("Continue with Google", "assets/google_logo.png", _handleGoogleSignIn),
        const SizedBox(height: 32),
        Center(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RegistrationScreen()),
              );
            },
            child: RichText(
              text: const TextSpan(
                text: "New tourist? ",
                style: TextStyle(color: Color(0xFF7F8C8D), fontSize: 15),
                children: [
                  TextSpan(
                    text: "Register here",
                    style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("COUNTRY", style: labelStyle),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDDE1E6)),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            underline: const SizedBox(),
            value: _selectedCountry.name,
            items: _countryNames.map((String name) {
              Country? country = CountryCodes.getCountryByName(name);
              return DropdownMenuItem<String>(
                value: name,
                child: Text('${country?.flag ?? "🌍"} $name (${country?.code ?? "+0"})'),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedCountry = CountryCodes.getCountryByName(newValue) ?? CountryCodes.getDefaultCountry();
                });
              }
            },
          ),
        ),
        const SizedBox(height: 24),
        const Text("MOBILE NUMBER", style: labelStyle),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFDDE1E6)),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: Text(
                "${_selectedCountry.flag} ${_selectedCountry.code}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(_phoneController, "98765 43210", Icons.phone_iphone)),
          ],
        ),
        const SizedBox(height: 32),
        _buildPrimaryButton(_isTimerActive ? "OTP Sent" : "Send OTP", _isTimerActive ? null : _handleSendOTP),
        const SizedBox(height: 40),
        const Center(
          child: Text(
            "ENTER 6-DIGIT OTP",
            style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.bold, color: Color(0xFF7F8C8D)),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) => _buildOtpBox(false)),
        ),
        const SizedBox(height: 24),
        Center(
          child: RichText(
            text: TextSpan(
              text: "Resend OTP in ",
              style: TextStyle(color: Color(0xFF7F8C8D)),
              children: [
                TextSpan(
                  text: "00:${_secondsRemaining.toString().padLeft(2, '0')}",
                  style: TextStyle(color: Color(0xFFFF7A00), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
         Center(
          child: GestureDetector(
            onTap: () {
               Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RegistrationScreen()),
              );
            },
            child: RichText(
              text: const TextSpan(
                text: "New tourist? ",
                style: TextStyle(color: Color(0xFF7F8C8D), fontSize: 15),
                children: [
                  TextSpan(
                    text: "Register here",
                    style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool obscure = false, Widget? suffixIcon}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        prefixIcon: Icon(icon, color: const Color(0xFF95A5A6), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE1E6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0E3A7E), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback? onPressed, {IconData? icon}) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF7A00),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    text,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, color: Colors.white.withValues(alpha:0.8), size: 20),
                  ]
                ],
              ),
      ),
    );
  }

  Widget _buildOutlineButton(String text, String assetPath, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFDDE1E6)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4285F4)),
              child: const Center(child: Text('G', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpBox(bool hasValue) {
    return Container(
      width: 50,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: hasValue ? const Color(0xFFFF7A00) : const Color(0xFFDDE1E6), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          hasValue ? "1" : "", // Simulation value
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFF7A00)),
        ),
      ),
    );
  }

  Widget _buildFooterItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2E7D32), size: 16),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

const labelStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.bold,
  color: Color(0xFF7F8C8D),
  letterSpacing: 0.5,
);