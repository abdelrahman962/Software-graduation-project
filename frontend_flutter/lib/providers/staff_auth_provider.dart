import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/staff_api_service.dart';
import '../models/user.dart';

class StaffAuthProvider extends ChangeNotifier {
  String? _token;
  User? _user;
  bool _isLoading = false;

  String? get token => _token;
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;
  String? get staffId => _user?.id;

  Future<void> loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('staff_token');

    final userId = prefs.getString('staff_id');
    final userEmail = prefs.getString('staff_email');

    if (_token != null && userId != null && userEmail != null) {
      _user = User(id: userId, email: userEmail, role: 'Staff');
      ApiService.setAuthToken(_token);
    }

    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await StaffApiService.login(email, password);

      if (response['token'] != null) {
        _token = response['token'];
        _user = User.fromJson(response['staff'] ?? {});

        ApiService.setAuthToken(_token);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('staff_token', _token!);
        await prefs.setString('staff_id', _user!.id);
        await prefs.setString('staff_email', _user!.email);

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
    await prefs.remove('staff_token');
    await prefs.remove('staff_id');
    await prefs.remove('staff_email');

    notifyListeners();
  }
}
