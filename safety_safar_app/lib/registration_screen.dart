import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'digital_id_screen.dart'; // Import the new success screen
import 'utils/country_codes.dart';  // Import country codes
import 'utils/api_config.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Step 1: Basic KYC
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String _nationality = "Indian";
  DateTime? _dob;
  String _gender = "Female";
  String _documentType = "Aadhaar";
  final _documentNumberController = TextEditingController();
  XFile? _profileImage;
  XFile? _idDocument;
  final ImagePicker _picker = ImagePicker();

  // Step 2: Itinerary
  DateTime? _arrivalDate;
  DateTime? _departureDate;
  final _accommodationController = TextEditingController();
  final _destinationsController = TextEditingController();

  // Step 3: Digital ID & Emergency
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  String _emergencyRelation = "Family";
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Country selector for phone
  late Country _selectedCountry;
  late List<String> _countryNames;

  @override
  void initState() {
    super.initState();
    _selectedCountry = CountryCodes.getDefaultCountry();
    _countryNames = CountryCodes.getCountryNames();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _documentNumberController.dispose();
    _accommodationController.dispose();
    _destinationsController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isProfile) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          if (isProfile) {
            _profileImage = image;
          } else {
            _idDocument = image;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _submitRegistration() async {
    if (_profileImage == null || _idDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both a profile photo and an ID document')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse(ApiConfig.register);
      final request = http.MultipartRequest('POST', uri);

      // Add text fields
      request.fields['first_name'] = _firstNameController.text;
      request.fields['last_name'] = _lastNameController.text;
      request.fields['email'] = _emailController.text;
      request.fields['phone'] = CountryCodes.formatPhoneNumber(_phoneController.text, _selectedCountry.code);
      request.fields['password'] = _passwordController.text;
      request.fields['nationality'] = _nationality;
      request.fields['dob'] = _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : "";
      request.fields['gender'] = _gender;
      request.fields['document_type'] = _documentType;
      request.fields['document_number'] = _documentNumberController.text;
      request.fields['arrival_date'] = _arrivalDate != null ? DateFormat('yyyy-MM-dd').format(_arrivalDate!) : "";
      request.fields['departure_date'] = _departureDate != null ? DateFormat('yyyy-MM-dd').format(_departureDate!) : "";
      request.fields['accommodation_details'] = _accommodationController.text;
      request.fields['itinerary_json'] = jsonEncode({'destinations': _destinationsController.text.split(',')});
      request.fields['emergency_name'] = _emergencyNameController.text;
      request.fields['emergency_phone'] = _emergencyPhoneController.text;
      request.fields['emergency_relation'] = _emergencyRelation;

      // Add files
      request.files.add(await http.MultipartFile.fromPath('profile_photo', _profileImage!.path));
      request.files.add(await http.MultipartFile.fromPath('id_document', _idDocument!.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (mounted) {
          // Navigate to Success Screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
            builder: (context) => DigitalIDScreen(
                userData: {
                  'first_name': _firstNameController.text,
                  'last_name': _lastNameController.text,
                  'email': _emailController.text,
                  'nationality': _nationality,
                },
              ),
            ),
          );
        }
      } else {
        String errorMsg = 'Registration failed';
        try {
          final errorData = jsonDecode(response.body);
          final detail = errorData['detail'];
          if (detail is List) {
            errorMsg = detail.map((e) => e['msg']).join(', ');
          } else {
            errorMsg = detail?.toString() ?? errorMsg;
          }
        } catch (_) {
          errorMsg = response.body.isNotEmpty ? response.body : errorMsg;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Submission Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _submitRegistration();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E3A7E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _prevStep,
        ),
        title: const Text(
          "Tourist Registration",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Step ${_currentStep + 1} of 3",
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (step) => setState(() => _currentStep = step),
              children: [
                _buildStep1KYC(),
                _buildStep2Itinerary(),
                _buildStep3Emergency(),
              ],
            ),
          ),
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: const Color(0xFF0E3A7E),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          _buildStepCircle(0, "Basic KYC"),
          _buildStepLine(0),
          _buildStepCircle(1, "Itinerary"),
          _buildStepLine(1),
          _buildStepCircle(2, "Digital ID"),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label) {
    bool isActive = _currentStep == step;
    bool isCompleted = _currentStep > step;
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFF7A00) : (isCompleted ? const Color(0xFF2E7D32) : Colors.white.withValues(alpha:0.2)),
            shape: BoxShape.circle,
            border: isActive ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : (step == 2 
                    ? const Icon(Icons.assignment_ind, color: Colors.white, size: 20)
                    : Text(
                        "${step + 1}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      )),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: isActive ? Colors.white : Colors.white70, fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
        )
      ],
    );
  }

  Widget _buildStepLine(int step) {
    bool isCompleted = _currentStep > step;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 24, left: 8, right: 8),
        color: isCompleted ? const Color(0xFF2E7D32) : Colors.white.withValues(alpha:0.2),
      ),
    );
  }

  Widget _buildStep1KYC() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Basic Details & KYC", style: headerStyle),
          const SizedBox(height: 8),
          const Text("Your identity information for secure digital ID generation", style: subHeaderStyle),
          const SizedBox(height: 24),
          
          InkWell(
            onTap: () => _pickImage(true),
            child: _buildUploadBox(
              "Upload Profile Photo", 
              _profileImage != null ? _profileImage!.name : "Tap to capture or choose from gallery", 
              Icons.camera_alt_outlined,
              isDone: _profileImage != null
            ),
          ),
          
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildInputField("FIRST NAME *", _firstNameController, "Enter first name")),
              const SizedBox(width: 16),
              Expanded(child: _buildInputField("LAST NAME *", _lastNameController, "Enter last name")),
            ],
          ),
          const SizedBox(height: 20),
          _buildToggleButtons("NATIONALITY *", ["Indian", "Foreign", "NRI"], _nationality, (val) => setState(() => _nationality = val)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildDatePicker("DATE OF BIRTH *", _dob, (date) => setState(() => _dob = date))),
              const SizedBox(width: 16),
              Expanded(child: _buildDropdown("GENDER", ["Female", "Male", "Other"], _gender, (val) => setState(() => _gender = val!))),
            ],
          ),
          const SizedBox(height: 20),
          _buildToggleButtons("DOCUMENT TYPE *", ["Aadhaar", "Passport", "Driving Lic."], _documentType, (val) => setState(() => _documentType = val)),
          const SizedBox(height: 20),
          _buildInputField("${_documentType.toUpperCase()} NUMBER *", _documentNumberController, "Enter document number"),
          const SizedBox(height: 24),
          InkWell(
            onTap: () => _pickImage(false),
            child: _buildUploadBox(
              "UPLOAD DOCUMENT *", 
              _idDocument != null ? _idDocument!.name : "Select your identity document file", 
              Icons.file_present_outlined, 
              isDone: _idDocument != null
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Itinerary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Travel Itinerary", style: headerStyle),
          const SizedBox(height: 8),
          const Text("Help us ensure your safety throughout your stay", style: subHeaderStyle),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _buildDatePicker("ARRIVAL DATE *", _arrivalDate, (date) => setState(() => _arrivalDate = date))),
              const SizedBox(width: 16),
              Expanded(child: _buildDatePicker("DEPARTURE DATE *", _departureDate, (date) => setState(() => _departureDate = date))),
            ],
          ),
          const SizedBox(height: 24),
          _buildInputField("ACCOMMODATION DETAILS *", _accommodationController, "Hotel Taj, Mumbai or Airbnb address", maxLines: 3),
          const SizedBox(height: 24),
          _buildInputField("PLANNED DESTINATIONS", _destinationsController, "Mumbai, Goa, Jaipur (Comma separated)", maxLines: 2),
          const SizedBox(height: 48),
          Center(
            child: Icon(Icons.map_outlined, size: 100, color: Colors.blue.withValues(alpha:0.1)),
          ),
          const SizedBox(height: 16),
          const Center(child: Text("Real-time geofencing will be active\nbased on your itinerary", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildStep3Emergency() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Digital Tourist ID & Contacts", style: headerStyle),
          const SizedBox(height: 8),
          const Text("Secure identity creation and primary emergency contacts", style: subHeaderStyle),
          const SizedBox(height: 32),
          _buildInputField("CONTACT PERSON NAME *", _emergencyNameController, "Enter name"),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(flex: 3, child: _buildInputField("PHONE NUMBER *", _emergencyPhoneController, "Enter mobile number")),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _buildDropdown("RELATION", ["Family", "Friend", "Work", "Other"], _emergencyRelation, (val) => setState(() => _emergencyRelation = val!))),
            ],
          ),
          const SizedBox(height: 40),
          const Text("Account Security", style: headerStyle),
          const SizedBox(height: 24),
          _buildInputField("EMAIL ADDRESS *", _emailController, "Enter email", icon: Icons.email_outlined),
          const SizedBox(height: 20),
          const Text("COUNTRY *", style: labelStyle),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFDDE1E6)),
              borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 20),
          const Text("MOBILE NUMBER *", style: labelStyle),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFDDE1E6)),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Text(
                  "${_selectedCountry.flag} ${_selectedCountry.code}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInputField("Mobile Number", _phoneController, "98765 43210", icon: Icons.phone_android_outlined),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildInputField(
            "CREATE PASSWORD *",
            _passwordController,
            "••••••••",
            icon: Icons.lock_outline,
            obscure: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha:0.3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 16),
                Expanded(child: Text("Ensure all details are accurate to avoid delays in Digital ID issuance.", style: TextStyle(color: Colors.orange, fontSize: 13))),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String hint, {int maxLines = 1, bool obscure = false, IconData? icon, Widget? suffixIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
            prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDDE1E6))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0E3A7E))),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? value, Function(DateTime) onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2100));
            if (date != null) onPicked(date);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDE1E6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value != null ? DateFormat('dd / MM / yyyy').format(value) : "Select Date", style: TextStyle(color: value != null ? Colors.black : Colors.grey.shade400)),
                const Icon(Icons.calendar_today, color: Colors.grey, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDDE1E6)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButtons(String label, List<String> options, String selected, Function(String) onSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 8),
        Row(
          children: options.map((opt) {
            bool isSelected = selected == opt;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => onSelected(opt),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0E3A7E) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? const Color(0xFF0E3A7E) : const Color(0xFFDDE1E6)),
                    ),
                    child: Center(
                      child: Text(
                        opt,
                        style: TextStyle(color: isSelected ? Colors.white : Colors.black54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUploadBox(String title, String subtitle, IconData icon, {bool isDone = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFFFF3E0) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDone ? const Color(0xFFFFCCBC) : const Color(0xFFDDE1E6), style: isDone ? BorderStyle.solid : BorderStyle.none),
      ),
      child: Column(
        children: [
          Icon(isDone ? Icons.insert_drive_file : icon, color: isDone ? const Color(0xFFFF7A00) : Colors.grey, size: 32),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: isDone ? const Color(0xFFFF7A00) : Colors.black, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: isDone ? const Color(0xFF7F8C8D) : Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: const BorderSide(color: Color(0xFFDDE1E6)),
                ),
                child: const Text("Back", style: TextStyle(color: Color(0xFF2C3E50), fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _currentStep == 2 ? "Complete Registration →" : "Continue →",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

const headerStyle = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50));
const subHeaderStyle = TextStyle(fontSize: 14, color: Color(0xFF7F8C8D));
const labelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7F8C8D), letterSpacing: 0.5);
