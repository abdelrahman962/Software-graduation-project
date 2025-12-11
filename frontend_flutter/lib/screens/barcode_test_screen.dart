import 'package:flutter/material.dart';
import '../utils/barcode_generator.dart';

class BarcodeTestScreen extends StatefulWidget {
  const BarcodeTestScreen({super.key});

  @override
  BarcodeTestScreenState createState() => BarcodeTestScreenState();
}

class BarcodeTestScreenState extends State<BarcodeTestScreen> {
  String? _generatedBarcode;
  bool _isValid = false;

  void _testBarcodeGeneration() {
    final barcode = BarcodeGenerator.generateUniqueBarcode();
    final isValid = BarcodeGenerator.isValidBarcodeFormat(barcode);

    setState(() {
      _generatedBarcode = barcode;
      _isValid = isValid;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barcode Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _testBarcodeGeneration,
              child: const Text('Generate Barcode'),
            ),
            const SizedBox(height: 20),
            if (_generatedBarcode != null) ...[
              Text('Generated Barcode: $_generatedBarcode'),
              Text('Is Valid Format: $_isValid'),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[200],
                child: Text(
                  _generatedBarcode!,
                  style: const TextStyle(fontSize: 18, fontFamily: 'monospace'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
