import 'dart:math';

class BarcodeGenerator {
  static String generateUniqueBarcode() {
    // Format: ORD-TIMESTAMP-RANDOM (e.g., ORD-1731456789000-A3B9)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _generateRandomString(4);
    return 'ORD-$timestamp-$random';
  }

  static String generateUniqueSampleBarcode() {
    // Format: SMP-TIMESTAMP-RANDOM (e.g., SMP-1731456789000-A3B9)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _generateRandomString(4);
    return 'SMP-$timestamp-$random';
  }

  static String _generateRandomString(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  // Validate barcode format
  static bool isValidBarcodeFormat(String barcode) {
    final regex = RegExp(r'^ORD-\d{13}-[A-Z0-9]{4}$');
    return regex.hasMatch(barcode);
  }

  // Validate sample barcode format
  static bool isValidSampleBarcodeFormat(String barcode) {
    final regex = RegExp(r'^SMP-\d{13}-[A-Z0-9]{4}$');
    return regex.hasMatch(barcode);
  }
}
