import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/doctor_auth_provider.dart';
import '../../services/doctor_api_service.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';

class DoctorPatientReportScreen extends StatefulWidget {
  final String orderId;

  const DoctorPatientReportScreen({super.key, required this.orderId});

  @override
  State<DoctorPatientReportScreen> createState() =>
      _DoctorPatientReportScreenState();
}

class _DoctorPatientReportScreenState extends State<DoctorPatientReportScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _orderInfo;
  List<dynamic> _results = [];

  @override
  void initState() {
    super.initState();
    _loadOrderResults();
  }

  Future<void> _loadOrderResults() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await DoctorApiService.getOrderResults(widget.orderId);

      if (mounted) {
        setState(() {
          _orderInfo = {
            'order_id': response['order_id'],
            'order_date': response['order_date'],
            'status': response['status'],
            'remarks': response['remarks'],
            'patient': response['patient'],
            'lab': response['lab'],
          };
          _results = response['results'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();

    final patient = _orderInfo?['patient'];
    final lab = _orderInfo?['lab'];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      lab?['name'] ?? 'Medical Laboratory',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    if (lab?['address'] != null)
                      pw.Text(
                        lab!['address'],
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    if (lab?['phone'] != null)
                      pw.Row(
                        children: [
                          pw.Text(
                            'Phone: ${lab!['phone']}',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Laboratory Test Report',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Patient Information
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Patient Information',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Divider(),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Name: ${patient?['full_name'] ?? 'N/A'}',
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'ID: ${patient?['identity_number'] ?? 'N/A'}',
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text('Gender: ${patient?['gender'] ?? 'N/A'}'),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Phone: ${patient?['phone_number'] ?? 'N/A'}',
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text('Email: ${patient?['email'] ?? 'N/A'}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Order Information
              pw.Text(
                'Order Date: ${_orderInfo?['order_date']?.substring(0, 10) ?? 'N/A'}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),

              // Test Results Table
              pw.Text(
                'Test Results',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
                cellAlignment: pw.Alignment.centerLeft,
                data: [
                  ['Test Name', 'Result', 'Units', 'Reference Range', 'Status'],
                  ..._results.map((result) {
                    return [
                      result['test_name'] ?? '',
                      result['result_value'] ?? 'Pending',
                      result['units'] ?? '',
                      result['reference_range'] ?? '',
                      result['status'] ?? '',
                    ];
                  }),
                ],
              ),

              // Remarks
              if (_results.any(
                (r) =>
                    r['remarks'] != null && r['remarks'].toString().isNotEmpty,
              ))
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(height: 20),
                    pw.Text(
                      'Remarks',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Text(
                        _results
                            .where(
                              (r) =>
                                  r['remarks'] != null &&
                                  r['remarks'].toString().isNotEmpty,
                            )
                            .map((r) => r['remarks'])
                            .join('\n\n'),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'pending':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'COMPLETED';
      case 'in_progress':
        return 'IN PROGRESS';
      case 'pending':
        return 'PENDING';
      default:
        return status.toUpperCase();
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.sync;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<DoctorAuthProvider>(context);

    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/doctor/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Report'),
        actions: [
          if (!_isLoading && _error == null && _results.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _generatePdf,
              tooltip: 'Download PDF',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadOrderResults,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _buildReportContent(authProvider),
    );
  }

  Widget _buildReportContent(DoctorAuthProvider authProvider) {
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No results available for this order',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    // Calculate overall status based on all tests
    final totalTests = _results.length;
    final completedTests = _results
        .where((r) => r['status'] == 'completed')
        .length;
    final inProgressTests = _results
        .where((r) => r['status'] == 'in_progress')
        .length;

    // Overall status logic
    String overallStatus;
    if (completedTests == totalTests) {
      overallStatus = 'completed';
    } else if (inProgressTests > 0) {
      overallStatus = 'in_progress';
    } else {
      overallStatus = 'pending';
    }

    final patient = _orderInfo?['patient'];
    final lab = _orderInfo?['lab'];

    return AppAnimations.pageDepthTransition(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_hospital,
                          color: AppTheme.primaryBlue,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lab?['name'] ?? 'Medical Laboratory',
                                style: AppTheme.medicalTextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              if (lab?['address'] != null)
                                Text(
                                  lab!['address'],
                                  style: AppTheme.medicalTextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMedium,
                                  ),
                                ),
                              if (lab?['phone'] != null)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone,
                                      size: 12,
                                      color: AppTheme.textMedium,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      lab!['phone'],
                                      style: AppTheme.medicalTextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Laboratory Test Report',
                                style: AppTheme.medicalTextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(overallStatus),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _getStatusText(overallStatus),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$completedTests/$totalTests Completed',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMedium,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Patient Information Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patient Information',
                          style: AppTheme.medicalTextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Divider(color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        _buildInfoRow('Name', patient?['full_name'] ?? 'N/A'),
                        _buildInfoRow(
                          'ID',
                          patient?['identity_number'] ?? 'N/A',
                        ),
                        _buildInfoRow('Gender', patient?['gender'] ?? 'N/A'),
                        _buildInfoRow(
                          'Phone',
                          patient?['phone_number'] ?? 'N/A',
                        ),
                        _buildInfoRow('Email', patient?['email'] ?? 'N/A'),
                      ],
                    ),
                  ),

                  Divider(color: Colors.grey[300], height: 1),

                  // Order Information
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: _buildInfoRow(
                      'Order Date',
                      _orderInfo?['order_date']?.substring(0, 10) ?? 'N/A',
                    ),
                  ),

                  Divider(color: Colors.grey[300], height: 1),

                  // Test Results Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Test Results',
                          style: AppTheme.medicalTextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._results.map(
                          (result) => _buildTestResultRow(result),
                        ),
                      ],
                    ),
                  ),

                  // Remarks Section
                  if (_results.any(
                    (r) =>
                        r['remarks'] != null &&
                        r['remarks'].toString().isNotEmpty,
                  ))
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Remarks',
                            style: AppTheme.medicalTextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._results
                              .where(
                                (r) =>
                                    r['remarks'] != null &&
                                    r['remarks'].toString().isNotEmpty,
                              )
                              .map(
                                (r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '• ${r['remarks']}',
                                    style: AppTheme.medicalTextStyle(
                                      fontSize: 14,
                                      color: AppTheme.textMedium,
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: AppTheme.medicalTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.medicalTextStyle(
                fontSize: 14,
                color: AppTheme.textMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResultRow(Map<String, dynamic> result) {
    final status = result['status'] ?? 'pending';
    final isAbnormal = result['is_abnormal'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: status == 'completed'
            ? (isAbnormal
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.05))
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: status == 'completed'
              ? (isAbnormal
                    ? Colors.orange.withValues(alpha: 0.3)
                    : Colors.green.withValues(alpha: 0.2))
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getStatusIcon(status),
                size: 20,
                color: _getStatusColor(status),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result['test_name'] ?? 'Unknown Test',
                      style: AppTheme.medicalTextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (result['test_code'] != null)
                      Text(
                        result['test_code'],
                        style: AppTheme.medicalTextStyle(
                          fontSize: 12,
                          color: AppTheme.textMedium,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
          if (status == 'completed' && result['result_value'] != null) ...[
            const SizedBox(height: 8),
            Divider(color: Colors.grey[300]),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Result',
                        style: AppTheme.medicalTextStyle(
                          fontSize: 12,
                          color: AppTheme.textMedium,
                        ),
                      ),
                      Text(
                        '${result['result_value']} ${result['units'] ?? ''}',
                        style: AppTheme.medicalTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isAbnormal ? Colors.orange : AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                if (result['reference_range'] != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reference Range',
                          style: AppTheme.medicalTextStyle(
                            fontSize: 12,
                            color: AppTheme.textMedium,
                          ),
                        ),
                        Text(
                          result['reference_range'],
                          style: AppTheme.medicalTextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
