import 'dart:convert';
import 'package:http/http.dart' as http;

class AdminService {
  static const String baseUrl = 'http://localhost:5000/api';

  // Get admin contact information for landing page
  static Future<Map<String, dynamic>> getContactInfo() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/contact-info'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'contact': data['contact'] ?? {}};
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to load contact information',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }
}
