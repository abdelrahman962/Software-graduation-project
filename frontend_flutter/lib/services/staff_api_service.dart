import 'api_service.dart';

class StaffApiService {
  // Auth
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    return await ApiService.post('/staff/login', {
      'username': username,
      'password': password,
    });
  }

  // Dashboard & Assigned Tests
  static Future<Map<String, dynamic>> getMyAssignedTests({
    String? statusFilter,
    String? deviceId,
  }) async {
    var url = '/staff/my-assigned-tests';
    final params = <String>[];

    if (statusFilter != null) params.add('status_filter=$statusFilter');
    if (deviceId != null) params.add('device_id=$deviceId');

    if (params.isNotEmpty) {
      url += '?${params.join('&')}';
    }

    return await ApiService.get(url);
  }

  // Get pending orders for barcode generation
  static Future<Map<String, dynamic>> getPendingOrders() async {
    return await ApiService.get('/staff/pending-orders');
  }

  // Get all orders for the lab
  static Future<Map<String, dynamic>> getAllLabOrders({
    String? status,
    String? patientId,
    String? startDate,
    String? endDate,
  }) async {
    var url = '/staff/orders';
    final params = <String>[];

    if (status != null) params.add('status=$status');
    if (patientId != null) params.add('patient_id=$patientId');
    if (startDate != null) params.add('startDate=$startDate');
    if (endDate != null) params.add('endDate=$endDate');

    if (params.isNotEmpty) {
      url += '?${params.join('&')}';
    }

    return await ApiService.get(url);
  }

  // Sample Collection
  static Future<Map<String, dynamic>> collectSample({
    required String detailId,
  }) async {
    return await ApiService.post('/staff/collect-sample', {
      'detail_id': detailId,
    });
  }

  // Auto-assign tests
  static Future<Map<String, dynamic>> autoAssignTests({
    required String orderId,
  }) async {
    return await ApiService.post('/staff/auto-assign-tests', {
      'order_id': orderId,
    });
  }

  // Result Upload
  static Future<Map<String, dynamic>> uploadResult({
    required String detailId,
    required String resultValue,
    String? remarks,
  }) async {
    return await ApiService.post('/staff/upload-result', {
      'detail_id': detailId,
      'result_value': resultValue,
      if (remarks != null) 'remarks': remarks,
    });
  }

  // Notifications
  static Future<Map<String, dynamic>> getNotifications(String staffId) async {
    return await ApiService.get('/staff/notifications/$staffId');
  }

  // Inventory
  static Future<Map<String, dynamic>> getInventoryItems({
    int page = 1,
    int limit = 20,
  }) async {
    final params = 'page=$page&limit=$limit';
    return await ApiService.get('/staff/inventory?$params');
  }

  static Future<Map<String, dynamic>> reportInventoryIssue({
    required String inventoryId,
    required String issueType,
    required int quantity,
    String? description,
  }) async {
    return await ApiService.post('/staff/report-inventory-issue', {
      'inventory_id': inventoryId,
      'issue_type': issueType,
      'quantity': quantity,
      if (description != null) 'description': description,
    });
  }

  static Future<Map<String, dynamic>> consumeInventory({
    required String inventoryId,
    required int quantity,
    String? reason,
  }) async {
    return await ApiService.post('/staff/consume-inventory', {
      'inventory_id': inventoryId,
      'quantity': quantity,
      if (reason != null) 'reason': reason,
    });
  }

  // Feedback
  static Future<Map<String, dynamic>> provideFeedback({
    required String targetType,
    String? targetId,
    required int rating,
    required String message,
    bool isAnonymous = false,
  }) async {
    return await ApiService.post('/staff/feedback', {
      'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
      'rating': rating,
      'message': message,
      'is_anonymous': isAnonymous,
    });
  }

  static Future<Map<String, dynamic>> getMyFeedback({
    int page = 1,
    int limit = 10,
    String? targetType,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (targetType != null) {
      queryParams['target_type'] = targetType;
    }

    final queryString = queryParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    return await ApiService.get('/staff/feedback?$queryString');
  }
}
