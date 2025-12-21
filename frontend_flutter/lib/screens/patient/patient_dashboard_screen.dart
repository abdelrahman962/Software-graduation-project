import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../providers/patient_auth_provider.dart';
import '../../services/patient_api_service.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';
import '../../widgets/system_feedback_form.dart';
import 'patient_profile_screen.dart';
import 'patient_order_report_screen.dart';
import '../../utils/responsive_utils.dart';

class PatientDashboardScreen extends StatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  bool _hasFeedbackSubmitted = false;
  bool _showFeedbackReminder = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _checkFeedbackStatus();
  }

  Future<void> _checkFeedbackStatus() async {
    try {
      final response = await PatientApiService.getMyFeedback();
      if (mounted) {
        setState(() {
          _hasFeedbackSubmitted =
              (response['feedbacks'] as List?)?.isNotEmpty ?? false;
          _showFeedbackReminder = !_hasFeedbackSubmitted;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasFeedbackSubmitted = false;
          _showFeedbackReminder = true;
        });
      }
    }
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final ordersResponse = await PatientApiService.getOrdersWithResults();

      if (mounted) {
        final ordersList = ordersResponse['orders'];
        setState(() {
          _orders = (ordersList is List) ? ordersList : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      // Try fallback to old endpoint if new one doesn't exist yet
      try {
        final fallbackResponse = await PatientApiService.getMyOrders();
        if (mounted) {
          final ordersList = fallbackResponse['orders'];
          setState(() {
            _orders = (ordersList is List) ? ordersList : [];
            _isLoading = false;
          });
        }
      } catch (fallbackError) {
        if (mounted) {
          setState(() {
            _orders = [];
            _isLoading = false;
          });

          // Show error message to user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load orders. Please try again later.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _loadOrders,
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<PatientAuthProvider>(context);

    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.goNamed('merged-login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResponsiveText(
                'Patient Dashboard',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              ResponsiveText(
                'Welcome back, ${authProvider.user?.fullName?.first ?? authProvider.user?.email ?? 'Patient'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            AppAnimations.bounce(
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: _showNotificationsDialog,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PatientProfileScreen(),
                  ),
                );
              },
            ),
            AppAnimations.scaleIn(
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await authProvider.logout();
                  await Future.delayed(const Duration(milliseconds: 50));
                  if (mounted) context.go('/');
                },
              ),
              delay: const Duration(milliseconds: 200),
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveText(
              'Patient Dashboard',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            ResponsiveText(
              'Welcome back, ${authProvider.user?.fullName?.first ?? authProvider.user?.email ?? 'Patient'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          AppAnimations.bounce(
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: _showNotificationsDialog,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PatientProfileScreen(),
                ),
              );
            },
          ),
          AppAnimations.scaleIn(
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await authProvider.logout();
                await Future.delayed(const Duration(milliseconds: 50));
                if (mounted) context.go('/');
              },
            ),
            delay: const Duration(milliseconds: 200),
          ),
        ],
      ),
      body: _orders.isEmpty ? _buildEmptyState() : _buildOrdersList(),
    );
  }

  Widget _buildEmptyState() {
    return AppAnimations.pageDepthTransition(
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppAnimations.floating(
              AppAnimations.morphIn(
                Icon(
                  Icons.science_outlined,
                  size: 80,
                  color: AppTheme.textLight,
                ),
                delay: const Duration(milliseconds: 200),
              ),
            ),
            const SizedBox(height: 16),
            AppAnimations.blurFadeIn(
              Text(
                'No orders yet',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppTheme.textLight),
              ),
              delay: const Duration(milliseconds: 400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList() {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _orders.length,
          itemBuilder: (context, index) {
            final order = _orders[index];
            return AppAnimations.slideInFromBottom(
              _buildOrderCard(order),
              delay: Duration(milliseconds: index * 100),
            );
          },
        ),
        if (_showFeedbackReminder)
          Positioned(
            bottom: 16,
            right: 16,
            child: AppAnimations.bounce(
              FloatingActionButton(
                onPressed: _showFeedbackDialog,
                backgroundColor: AppTheme.primaryBlue,
                child: const Icon(Icons.feedback, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: const Text('No new notifications at this time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(dynamic order) {
    final orderDate = DateTime.parse(order['order_date']);
    final status = order['status'] ?? 'unknown';
    final testCount = order['test_count'] ?? 0;
    final labName = order['owner_id']?['lab_name'] ?? 'Medical Lab';

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'completed':
        statusColor = AppTheme.successGreen;
        statusIcon = Icons.check_circle;
        break;
      case 'processing':
        statusColor = AppTheme.warningYellow;
        statusIcon = Icons.hourglass_top;
        break;
      case 'pending':
        statusColor = AppTheme.primaryBlue;
        statusIcon = Icons.schedule;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date and lab name
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMM dd, yyyy').format(orderDate),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        labName,
                        style: const TextStyle(
                          color: AppTheme.textMedium,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Order info
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    Icons.science,
                    '$testCount Test${testCount != 1 ? 's' : ''}',
                    'Medical tests ordered',
                  ),
                ),
                if (order['total_cost'] != null)
                  Expanded(
                    child: _buildInfoItem(
                      Icons.attach_money,
                      'ILS ${order['total_cost'].toStringAsFixed(2)}',
                      'Total cost',
                    ),
                  ),
              ],
            ),
            if (order['order_details'] != null &&
                order['order_details'].isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Tests Ordered:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (order['order_details'] as List).take(3).map((
                  detail,
                ) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      detail['test_name'] ?? 'Unknown Test',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMedium,
                      ),
                    ),
                  );
                }).toList(),
              ),
              if ((order['order_details'] as List).length > 3)
                Text(
                  '+${(order['order_details'] as List).length - 3} more tests',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMedium,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
            const SizedBox(height: 20),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showOrderResults(order),
                    icon: const Icon(Icons.science, size: 18),
                    label: const Text('View Results'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showOrderBill(order),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('View Bill'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryBlue),
                      foregroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showOrderResults(dynamic order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PatientOrderReportScreen(orderId: order['order_id']),
      ),
    );
  }

  void _showOrderBill(dynamic order) async {
    // Navigate to bill details screen
    GoRouter.of(
      context,
    ).push('/patient-dashboard/bill-details/${order['order_id']}');
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => SystemFeedbackForm(
        onSubmit: (feedbackData) async {
          try {
            await PatientApiService.provideFeedback(
              targetType: feedbackData['target_type'],
              targetId: feedbackData['target_id'],
              rating: feedbackData['rating'],
              message: feedbackData['message'],
              isAnonymous: feedbackData['is_anonymous'],
            );
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you for your feedback!'),
                  backgroundColor: AppTheme.successGreen,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to submit feedback: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }
}

class _OrderDetailsModal extends StatefulWidget {
  final dynamic order;
  final dynamic invoice;
  final ScrollController scrollController;
  final bool initialShowResults;

  const _OrderDetailsModal({
    required this.order,
    this.invoice,
    required this.scrollController,
    this.initialShowResults = true,
  });

  @override
  State<_OrderDetailsModal> createState() => _OrderDetailsModalState();
}

class _OrderDetailsModalState extends State<_OrderDetailsModal> {
  late bool _showTestResults; // true = Test Results, false = Bill Details

  @override
  void initState() {
    super.initState();
    _showTestResults = widget.initialShowResults;
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final status = order['status'] ?? 'unknown';

    Color statusColor;
    switch (status) {
      case 'completed':
        statusColor = AppTheme.successGreen;
        break;
      case 'processing':
        statusColor = AppTheme.warningYellow;
        break;
      case 'pending':
        statusColor = AppTheme.primaryBlue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Title and toggle
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _showTestResults ? 'Test Results' : 'Bill Details',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        // Test Results Tab
                        GestureDetector(
                          onTap: () => setState(() => _showTestResults = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _showTestResults
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: _showTestResults
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.science,
                                  size: 16,
                                  color: _showTestResults
                                      ? statusColor
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Test Results',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _showTestResults
                                        ? statusColor
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Bill Details Tab
                        GestureDetector(
                          onTap: () => setState(() => _showTestResults = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: !_showTestResults
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: !_showTestResults
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 16,
                                  color: !_showTestResults
                                      ? statusColor
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Bill Details',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: !_showTestResults
                                        ? statusColor
                                        : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: Container(
            color: Colors.grey[50],
            child: _showTestResults
                ? _buildTestResultsContent()
                : _buildBillContent(context),
          ),
        ),
      ],
    );
  }

  Widget _buildTestResultsContent() {
    final order = widget.order;
    final orderDate = DateTime.parse(order['order_date']);
    final status = order['status'] ?? 'unknown';

    Color statusColor;
    switch (status) {
      case 'completed':
        statusColor = AppTheme.successGreen;
        break;
      case 'processing':
        statusColor = AppTheme.warningYellow;
        break;
      case 'pending':
        statusColor = AppTheme.primaryBlue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // Order Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.science, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order['order_id'].toString().substring(0, min(8, order['order_id'].toString().length)).toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          DateFormat(
                            'MMM dd, yyyy - hh:mm a',
                          ).format(orderDate),
                          style: const TextStyle(
                            color: AppTheme.textMedium,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (order['order_details'] != null &&
                  order['order_details'].isNotEmpty) ...[
                const Text(
                  'Tests Ordered:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                ...(order['order_details'] as List).map((detail) {
                  final testName = detail['test_name'] ?? 'Unknown Test';
                  final result = detail['result'];
                  final resultComponent = detail['result_component'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getTestStatusColor(
                          detail['status'] ?? 'pending',
                        ).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                testName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getTestStatusColor(
                                  detail['status'] ?? 'pending',
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                (detail['status'] ?? 'pending').toUpperCase(),
                                style: TextStyle(
                                  color: _getTestStatusColor(
                                    detail['status'] ?? 'pending',
                                  ),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (result != null && resultComponent != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Result: ${result['value'] ?? 'N/A'} ${resultComponent['unit'] ?? ''}',
                                      style: const TextStyle(
                                        color: AppTheme.textDark,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Range: ${resultComponent['normal_range_min'] ?? 'N/A'} - ${resultComponent['normal_range_max'] ?? 'N/A'} ${resultComponent['unit'] ?? ''}',
                                      style: const TextStyle(
                                        color: AppTheme.textMedium,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                _isResultNormal(result, resultComponent)
                                    ? Icons.check_circle
                                    : Icons.warning,
                                color: _isResultNormal(result, resultComponent)
                                    ? AppTheme.successGreen
                                    : AppTheme.errorRed,
                                size: 20,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBillContent(BuildContext context) {
    final invoice = widget.invoice;
    final order = widget.order;
    final authProvider = Provider.of<PatientAuthProvider>(
      context,
      listen: false,
    );

    if (invoice == null) {
      return const Center(child: Text('No bill information available'));
    }

    final invoiceDate = DateTime.parse(
      invoice['created_at'] ?? order['order_date'],
    );
    final paymentStatus = 'paid'; // Bills are always considered paid

    Color paymentColor;
    IconData paymentIcon;

    switch (paymentStatus) {
      case 'paid':
        paymentColor = AppTheme.successGreen;
        paymentIcon = Icons.check_circle;
        break;
      case 'pending':
        paymentColor = AppTheme.warningYellow;
        paymentIcon = Icons.schedule;
        break;
      case 'overdue':
        paymentColor = AppTheme.errorRed;
        paymentIcon = Icons.warning;
        break;
      default:
        paymentColor = Colors.grey;
        paymentIcon = Icons.help;
    }

    // Calculate total from order details
    double totalAmount = 0.0;
    if (order['order_details'] != null) {
      for (final detail in order['order_details']) {
        final price = detail['price'] ?? 0.0;
        totalAmount += price is num ? price.toDouble() : 0.0;
      }
    }

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // Patient Information
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Patient Information',
                style: AppTheme.medicalTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                'Name',
                authProvider.user?.fullName != null
                    ? _getPatientFullName(authProvider.user!)
                    : authProvider.user?.email ?? 'N/A',
              ),
              _buildInfoRow(
                'ID Number',
                authProvider.user?.identityNumber ?? 'N/A',
              ),
              _buildInfoRow('Gender', authProvider.user?.gender ?? 'N/A'),
              _buildInfoRow(
                'Date of Birth',
                authProvider.user?.birthday != null
                    ? '${authProvider.user!.birthday!.day.toString().padLeft(2, '0')}/${authProvider.user!.birthday!.month.toString().padLeft(2, '0')}/${authProvider.user!.birthday!.year}'
                    : 'N/A',
              ),
              _buildInfoRow(
                'Order Date',
                DateFormat(
                  'MMM dd, yyyy',
                ).format(DateTime.parse(order['order_date'])),
              ),
            ],
          ),
        ),

        // Invoice Summary
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: paymentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(paymentIcon, color: paymentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invoice #${invoice['_id'].toString().substring(0, min(8, invoice['_id'].toString().length)).toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          DateFormat('MMM dd, yyyy').format(invoiceDate),
                          style: const TextStyle(
                            color: AppTheme.textMedium,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: paymentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      paymentStatus.toUpperCase(),
                      style: TextStyle(
                        color: paymentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Test Costs
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Test Costs',
                style: AppTheme.medicalTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),
              if (order['order_details'] != null &&
                  order['order_details'].isNotEmpty) ...[
                ...(order['order_details'] as List).map((detail) {
                  final testName = detail['test_name'] ?? 'Unknown Test';
                  final price = detail['price'] ?? 0.0;
                  final priceDouble = price is num ? price.toDouble() : 0.0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            testName,
                            style: const TextStyle(color: AppTheme.textDark),
                          ),
                        ),
                        Text(
                          'ILS ${priceDouble.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    Text(
                      'ILS ${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Text('No test details available'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Color _getTestStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.successGreen;
      case 'processing':
        return AppTheme.warningYellow;
      case 'pending':
        return AppTheme.primaryBlue;
      default:
        return Colors.grey;
    }
  }

  bool _isResultNormal(dynamic result, dynamic resultComponent) {
    if (result == null || resultComponent == null) return false;

    final value = result['value'];
    final minRange = resultComponent['normal_range_min'];
    final maxRange = resultComponent['normal_range_max'];

    if (value == null || minRange == null || maxRange == null) return false;

    final numValue = num.tryParse(value.toString());
    final numMin = num.tryParse(minRange.toString());
    final numMax = num.tryParse(maxRange.toString());

    if (numValue == null || numMin == null || numMax == null) return false;

    return numValue >= numMin && numValue <= numMax;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTheme.medicalTextStyle(
                fontSize: 12,
                color: AppTheme.textMedium,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppTheme.medicalTextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPatientFullName(user) {
    if (user?.fullName != null) {
      final first = user!.fullName!.first;
      final middle = user.fullName!.middle;
      final last = user.fullName!.last;

      final nameParts = [first];
      if (middle != null && middle.isNotEmpty) {
        nameParts.add(middle);
      }
      nameParts.add(last);

      return nameParts.join(' ');
    }
    return user?.email ?? 'N/A';
  }
}
