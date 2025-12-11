import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/doctor_api_service.dart';
import '../models/user.dart';

class DoctorAuthProvider extends ChangeNotifier {
  String? _token;
  User? _user;
  bool _isLoading = false;

  String? get token => _token;
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  String? get doctorId => _user?.id;

  Future<void> loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('doctor_token');

    final userId = prefs.getString('doctor_id');
    final userEmail = prefs.getString('doctor_email');

    if (_token != null && userId != null && userEmail != null) {
      _user = User(id: userId, email: userEmail, role: 'Doctor');
      ApiService.setAuthToken(_token);
    }

    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await DoctorApiService.login(email, password);

      if (response['token'] != null) {
        _token = response['token'];
        _user = User.fromJson(response['doctor'] ?? {});

        ApiService.setAuthToken(_token);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('doctor_token', _token!);
        await prefs.setString('doctor_id', _user!.id);
        await prefs.setString('doctor_email', _user!.email);

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
    await prefs.remove('doctor_token');
    await prefs.remove('doctor_id');
    await prefs.remove('doctor_email');

    notifyListeners();
  }
}
