import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/patient_api_service.dart';
import '../models/user.dart';

class PatientAuthProvider extends ChangeNotifier {
  String? _token;
  User? _user;
  bool _isLoading = false;

  String? get token => _token;
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  String? get patientId => _user?.id;

  Future<void> loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('patient_token');

    if (_token != null) {
      ApiService.setAuthToken(_token);

      // Try to load full user data from profile endpoint
      try {
        final profileResponse = await PatientApiService.getProfile();
        _user = User.fromJson(profileResponse);
      } catch (e) {
        // If profile fails, fallback to basic user data
        final userId = prefs.getString('patient_id');
        final userEmail = prefs.getString('patient_email');
        if (userId != null && userEmail != null) {
          _user = User(id: userId, email: userEmail, role: 'Patient');
        }
      }
    }

    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await PatientApiService.login(email, password);

      if (response['token'] != null) {
        _token = response['token'];
        _user = User.fromJson(response['patient'] ?? {});

        ApiService.setAuthToken(_token);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('patient_token', _token!);
        await prefs.setString('patient_id', _user!.id);
        await prefs.setString('patient_email', _user!.email);

        _isLoading = false;
        notifyListeners();

        return {'success': true, 'message': 'Login successful'};
      }

      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': response['message'] ?? 'Login failed',
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    ApiService.setAuthToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('patient_token');
    await prefs.remove('patient_id');
    await prefs.remove('patient_email');

    notifyListeners();
  }
}
