/// Country codes mapping for international phone number support
class Country {
  final String name;
  final String code;
  final String flag;
  final int phoneLength;

  const Country({
    required this.name,
    required this.code,
    required this.flag,
    required this.phoneLength,
  });
}

class CountryCodes {
  static const List<Country> countries = [
    // Popular Tourist Destinations
    Country(name: "India", code: "+91", flag: "🇮🇳", phoneLength: 10),
    Country(name: "United States", code: "+1", flag: "🇺🇸", phoneLength: 10),
    Country(name: "United Kingdom", code: "+44", flag: "🇬🇧", phoneLength: 10),
    Country(name: "Canada", code: "+1", flag: "🇨🇦", phoneLength: 10),
    Country(name: "Australia", code: "+61", flag: "🇦🇺", phoneLength: 9),
    Country(name: "Germany", code: "+49", flag: "🇩🇪", phoneLength: 11),
    Country(name: "France", code: "+33", flag: "🇫🇷", phoneLength: 9),
    Country(name: "Japan", code: "+81", flag: "🇯🇵", phoneLength: 10),
    Country(name: "China", code: "+86", flag: "🇨🇳", phoneLength: 11),
    Country(name: "Singapore", code: "+65", flag: "🇸🇬", phoneLength: 8),
    Country(name: "Thailand", code: "+66", flag: "🇹🇭", phoneLength: 9),
    Country(name: "Malaysia", code: "+60", flag: "🇲🇾", phoneLength: 10),
    Country(name: "Indonesia", code: "+62", flag: "🇮🇩", phoneLength: 10),
    Country(name: "Philippines", code: "+63", flag: "🇵🇭", phoneLength: 10),
    Country(name: "Vietnam", code: "+84", flag: "🇻🇳", phoneLength: 9),
    Country(name: "South Korea", code: "+82", flag: "🇰🇷", phoneLength: 10),
    Country(name: "Thailand", code: "+66", flag: "🇹🇭", phoneLength: 9),
    Country(name: "Nepal", code: "+977", flag: "🇳🇵", phoneLength: 10),
    Country(name: "Pakistan", code: "+92", flag: "🇵🇰", phoneLength: 10),
    Country(name: "Bangladesh", code: "+880", flag: "🇧🇩", phoneLength: 10),
    Country(name: "Sri Lanka", code: "+94", flag: "🇱🇰", phoneLength: 9),
    Country(name: "Maldives", code: "+960", flag: "🇲🇻", phoneLength: 7),
    Country(name: "Italy", code: "+39", flag: "🇮🇹", phoneLength: 10),
    Country(name: "Spain", code: "+34", flag: "🇪🇸", phoneLength: 9),
    Country(name: "Portugal", code: "+351", flag: "🇵🇹", phoneLength: 9),
    Country(name: "Greece", code: "+30", flag: "🇬🇷", phoneLength: 10),
    Country(name: "Switzerland", code: "+41", flag: "🇨🇭", phoneLength: 9),
    Country(name: "Netherlands", code: "+31", flag: "🇳🇱", phoneLength: 9),
    Country(name: "Belgium", code: "+32", flag: "🇧🇪", phoneLength: 9),
    Country(name: "Austria", code: "+43", flag: "🇦🇹", phoneLength: 10),
    Country(name: "New Zealand", code: "+64", flag: "🇳🇿", phoneLength: 9),
    Country(name: "Mexico", code: "+52", flag: "🇲🇽", phoneLength: 10),
    Country(name: "Brazil", code: "+55", flag: "🇧🇷", phoneLength: 11),
    Country(name: "Argentina", code: "+54", flag: "🇦🇷", phoneLength: 10),
    Country(name: "United Arab Emirates", code: "+971", flag: "🇦🇪", phoneLength: 9),
    Country(name: "Saudi Arabia", code: "+966", flag: "🇸🇦", phoneLength: 9),
    Country(name: "Qatar", code: "+974", flag: "🇶🇦", phoneLength: 8),
    Country(name: "Egypt", code: "+20", flag: "🇪🇬", phoneLength: 10),
    Country(name: "South Africa", code: "+27", flag: "🇿🇦", phoneLength: 9),
  ];

  /// Get country by code
  static Country? getCountryByCode(String code) {
    try {
      return countries.firstWhere((c) => c.code == code);
    } catch (e) {
      return null;
    }
  }

  /// Get country by name
  static Country? getCountryByName(String name) {
    try {
      return countries.firstWhere((c) => c.name.toLowerCase() == name.toLowerCase());
    } catch (e) {
      return null;
    }
  }

  /// Get default country (India)
  static Country getDefaultCountry() {
    return countries.first; // India
  }

  /// Format phone number with country code
  static String formatPhoneNumber(String phone, String countryCode) {
    // Remove any existing + or spaces
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    return '$countryCode$cleanPhone';
  }

  /// Get countries list for dropdown
  static List<String> getCountryNames() {
    return countries.map((c) => c.name).toList();
  }

  /// Get country code with flag
  static String getCountryCodeWithFlag(String name) {
    Country? country = getCountryByName(name);
    if (country != null) {
      return '${country.flag} ${country.code}';
    }
    return '🇮🇳 +91'; // Default
  }
}
