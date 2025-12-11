import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/barcode_generator.dart';

class BarcodeService {
  static const String baseUrl = 'http://localhost:5000/api';

  // Generate sample barcode on frontend and send to backend
  static Future<Map<String, dynamic>> generateSampleBarcode(
    String detailId,
    String token,
  ) async {
    try {
      // Generate sample barcode on frontend
      final barcode = BarcodeGenerator.generateUniqueSampleBarcode();

      // Send to backend for validation and storage
      final response = await http.post(
        Uri.parse('$baseUrl/staff/generate-sample-barcode/$detailId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'frontend_barcode': barcode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'barcode': barcode,
          'message': data['message'] ?? 'Sample barcode generated successfully',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to generate sample barcode',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // Generate barcode on frontend and send to backend (for orders)
  static Future<Map<String, dynamic>> generateBarcode(
    String orderId,
    String token,
  ) async {
    try {
      // Generate barcode on frontend
      final barcode = BarcodeGenerator.generateUniqueBarcode();

      // Send to backend for validation and storage
      final response = await http.post(
        Uri.parse('$baseUrl/staff/generate-barcode/$orderId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'frontend_barcode': barcode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'barcode': barcode,
          'message': data['message'] ?? 'Barcode generated successfully',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Failed to generate barcode',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // Get barcode for an order (if already exists)
  static Future<String?> getOrderBarcode(String orderId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/staff/order-details/$orderId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final orderDetails = data['order_details'];
        if (orderDetails != null && orderDetails.isNotEmpty) {
          return orderDetails[0]['order_barcode'];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
