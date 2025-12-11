import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  // Initialize auth state from local storage
  Future<void> loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('admin_token');
    final userJson = prefs.getString('user_data');
    if (userJson != null) {
      _user = Map<String, dynamic>.from(
        // You would parse JSON here
        {},
      );
    }
    // Set token in API service if available
    if (_token != null) {
      ApiService.setAuthToken(_token);
    }
    notifyListeners();
  }

  // Admin login
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.post('/admin/login', {
        'username': username, // Backend expects 'username' not 'email'
        'password': password,
      });

      // Backend sends success message, not success boolean
      if (response['token'] != null) {
        _token = response['token'];
        _user = response['admin'];

        // Set token in API service for subsequent requests
        ApiService.setAuthToken(_token);

        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('admin_token', _token!);
        await prefs.setString('user_data', response['admin'].toString());

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    _token = null;
    _user = null;

    // Clear local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
    await prefs.remove('admin_id');
    await prefs.remove('admin_email');
    await prefs.remove('user_data');

    notifyListeners();
  }

  // Get token for API requests
  String? getAuthToken() {
    return _token;
  }
}
