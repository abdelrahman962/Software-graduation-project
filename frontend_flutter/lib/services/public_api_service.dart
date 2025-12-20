import 'api_service.dart';

class PublicApiService {
  // Submit lab owner registration with plan info
  static Future<Map<String, dynamic>> submitOwnerRegistration({
    required String firstName,
    required String middleName,
    required String lastName,
    required String identityNumber,
    required String birthday,
    required String gender,
    required String phone,
    required String address,
    required String email,
    required String selectedPlan,
    String? socialStatus,
    String? qualification,
    String? professionLicense,
    String? bankIban,
  }) async {
    return await ApiService.post('/owner/request-access', {
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'identity_number': identityNumber,
      'birthday': birthday,
      'gender': gender,
      'phone': phone,
      'address': address,
      'email': email,
      'selected_plan': selectedPlan,
      if (socialStatus != null) 'social_status': socialStatus,
      if (qualification != null) 'qualification': qualification,
      if (professionLicense != null) 'profession_license': professionLicense,
      if (bankIban != null) 'bank_iban': bankIban,
    });
  }

  // Submit registration (get token)
  static Future<Map<String, dynamic>> submitRegistration({
    required String labId,
    required Map<String, dynamic>
    fullName, // {first: String, middle: String?, last: String}
    required String identityNumber,
    required String birthday,
    required String gender,
    required String phoneNumber,
    required String email,
    required String address,
    required List<String> testIds,
    String? socialStatus,
    String? insuranceProvider,
    String? insuranceNumber,
    String? remarks,
  }) async {
    return await ApiService.post('/public/submit-registration', {
      'lab_id': labId,
      'full_name': fullName,
      'identity_number': identityNumber,
      'birthday': birthday,
      'gender': gender,
      'phone_number': phoneNumber,
      'email': email,
      'address': address,
      'test_ids': testIds,
      if (socialStatus != null) 'social_status': socialStatus,
      if (insuranceProvider != null) 'insurance_provider': insuranceProvider,
      if (insuranceNumber != null) 'insurance_number': insuranceNumber,
      if (remarks != null) 'remarks': remarks,
    });
  }

  // Verify registration token
  static Future<Map<String, dynamic>> verifyToken(String token) async {
    return await ApiService.get('/public/register/verify/$token');
  }

  // Complete registration
  static Future<Map<String, dynamic>> completeRegistration({
    required String token,
    required String password,
    required Map<String, dynamic> personalInfo,
  }) async {
    return await ApiService.post('/public/register/complete', {
      'token': token,
      'password': password,
      ...personalInfo,
    });
  }

  // Get labs
  static Future<Map<String, dynamic>> getLabs() async {
    return await ApiService.get('/public/labs');
  }

  // Get lab tests
  static Future<Map<String, dynamic>> getLabTests(String labId) async {
    return await ApiService.get('/public/labs/$labId/tests');
  }

  // Get system feedback for marketing
  static Future<Map<String, dynamic>> getSystemFeedback({
    int limit = 10,
    int minRating = 4,
  }) async {
    return await ApiService.get(
      '/public/feedback/system?limit=$limit&minRating=$minRating',
    );
  }

  // Submit contact form for laboratory owners interested in the system
  static Future<Map<String, dynamic>> submitContactForm({
    required String name,
    required String email,
    String? phone,
    required String labName,
    required String message,
  }) async {
    return await ApiService.post('/public/contact', {
      'name': name,
      'email': email,
      'phone': phone,
      'lab_name': labName,
      'message': message,
    });
  }

  // Register new lab owner (self-service registration)
  static Future<Map<String, dynamic>> registerOwner({
    required Map<String, String> fullName, // {first, middle, last}
    required String identityNumber,
    required String birthday,
    required String gender,
    required String phoneNumber,
    required String email,
    required Map<String, String> address, // {city, street, building_number}
    required String labName,
    required String labLicenseNumber,
    required String username,
    required String password,
    int subscriptionPeriodMonths = 1, // Default 1 month
  }) async {
    return await ApiService.post('/public/owner/register', {
      'full_name': fullName,
      'identity_number': identityNumber,
      'birthday': birthday,
      'gender': gender,
      'phone_number': phoneNumber,
      'email': email,
      'address': address,
      'lab_name': labName,
      'lab_license_number': labLicenseNumber,
      'username': username,
      'password': password,
      'subscription_period_months': subscriptionPeriodMonths,
    });
  }
}
