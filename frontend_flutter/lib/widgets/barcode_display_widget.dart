// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../services/barcode_service.dart';

class BarcodeDisplayWidget extends StatefulWidget {
  final String? orderId;
  final String? detailId;
  final String? initialBarcode;
  final String token;
  final VoidCallback? onBarcodeGenerated;

  // ignore: use_super_parameters
  const BarcodeDisplayWidget({
    Key? key,
    this.orderId,
    this.detailId,
    this.initialBarcode,
    required this.token,
    this.onBarcodeGenerated,
  }) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _BarcodeDisplayWidgetState createState() => _BarcodeDisplayWidgetState();
}

class _BarcodeDisplayWidgetState extends State<BarcodeDisplayWidget> {
  String? _barcode;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _barcode = widget.initialBarcode;
  }

  Future<void> _generateBarcode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = widget.detailId != null
          ? await BarcodeService.generateSampleBarcode(
              widget.detailId!,
              widget.token,
            )
          : await BarcodeService.generateBarcode(widget.orderId!, widget.token);

      if (result['success']) {
        setState(() {
          _barcode = result['barcode'];
        });
        widget.onBarcodeGenerated?.call();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result['message'])));
      } else {
        setState(() {
          _errorMessage = result['message'];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate barcode: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.detailId != null ? 'Sample Barcode' : 'Order Barcode',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            if (_barcode != null) ...[
              // Display barcode
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: _barcode!,
                  width: 200,
                  height: 80,
                  drawText: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _barcode!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _generateBarcode,
                icon: const Icon(Icons.refresh),
                label: const Text('Regenerate Barcode'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ] else ...[
              // No barcode yet
              const Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No barcode generated yet',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _generateBarcode,
                  icon: const Icon(Icons.add),
                  label: const Text('Generate Barcode'),
                ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
