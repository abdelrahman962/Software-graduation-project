import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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

    // Show loading while auth state is being determined
    if (authProvider.token == null && authProvider.user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
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
