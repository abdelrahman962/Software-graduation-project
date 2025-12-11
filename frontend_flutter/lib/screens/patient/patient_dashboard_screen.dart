import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/patient_auth_provider.dart';
import '../../services/patient_api_service.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../widgets/animations.dart';
import '../../widgets/system_feedback_form.dart';

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
      print('Error loading orders: $e');

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
        print('Fallback also failed: $fallbackError');
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient Dashboard',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
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
          AppAnimations.scaleIn(
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await authProvider.logout();
                // Small delay to ensure logout is complete before navigation
                await Future.delayed(const Duration(milliseconds: 50));
                if (mounted) context.go('/');
              },
            ),
            delay: 200.ms,
          ),
        ],
      ),
      body: _buildResultsTab(authProvider),
    );
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
              setState(() {
                _hasFeedbackSubmitted = true;
                _showFeedbackReminder = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you for your feedback!'),
                  backgroundColor: Colors.green,
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

  Widget _buildResultsTab(PatientAuthProvider authProvider) {
    if (_orders.isEmpty) {
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
                  delay: 200.ms,
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
                delay: 400.ms,
              ),
            ],
          ),
        ),
      );
    }

    return AppAnimations.pageDepthTransition(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_showFeedbackReminder)
              AppAnimations.elasticSlideIn(
                _buildFeedbackReminderBanner(),
                delay: 50.ms,
              ),
            if (_showFeedbackReminder) const SizedBox(height: 16),

            // Title
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Icon(Icons.assignment, color: AppTheme.primaryBlue, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'My Laboratory Orders',
                    style: AppTheme.medicalTextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            ),

            // Order Cards
            ..._orders.asMap().entries.map((entry) {
              final index = entry.key;
              final order = entry.value;
              return AppAnimations.slideInFromRight(
                _buildOrderCard(order),
                delay: Duration(milliseconds: 100 * index),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['order_id'];
    final barcode = order['barcode'] ?? 'N/A';
    final orderDate = order['order_date']?.substring(0, 10) ?? 'N/A';
    final doctorName = order['doctor_name'] ?? 'Not assigned';
    final totalTests = order['total_tests'] ?? 0;
    final completedTests = order['completed_tests'] ?? 0;
    final inProgressTests = order['in_progress_tests'] ?? 0;
    final pendingTests = order['pending_tests'] ?? 0;
    final hasResults = order['has_results'] ?? false;

    // Determine card status color
    Color statusColor;
    String statusText;
    if (completedTests == totalTests) {
      statusColor = AppTheme.successGreen;
      statusText = 'All tests completed';
    } else if (inProgressTests > 0) {
      statusColor = AppTheme.warningYellow;
      statusText = '$inProgressTests test(s) in progress';
    } else {
      statusColor = AppTheme.primaryBlue;
      statusText = '$pendingTests test(s) pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: AnimatedCard(
        child: InkWell(
          onTap: hasResults
              ? () {
                  context.go('/patient-dashboard/order-report/$orderId');
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.assignment,
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #$barcode',
                            style: AppTheme.medicalTextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          Text(
                            orderDate,
                            style: AppTheme.medicalTextStyle(
                              fontSize: 13,
                              color: AppTheme.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$completedTests/$totalTests',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Status indicator
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        completedTests == totalTests
                            ? Icons.check_circle
                            : (inProgressTests > 0
                                  ? Icons.pending
                                  : Icons.schedule),
                        color: statusColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusText,
                          style: AppTheme.medicalTextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Doctor info
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: AppTheme.textMedium,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        doctorName,
                        style: AppTheme.medicalTextStyle(
                          fontSize: 13,
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ),
                  ],
                ),

                if (hasResults) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'View Report',
                        style: AppTheme.medicalTextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        color: AppTheme.primaryBlue,
                        size: 18,
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'No results available yet',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textLight,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackReminderBanner() {
    return AnimatedCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue.withValues(alpha: 0.1),
              AppTheme.secondaryTeal.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryBlue.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.feedback_outlined,
                color: AppTheme.primaryBlue,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share Your Experience',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Help us improve by sharing your feedback about the system',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showFeedbackDialog(),
                  icon: const Icon(Icons.rate_review, size: 18),
                  label: const Text('Provide Feedback'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showFeedbackReminder = false;
                    });
                  },
                  child: const Text(
                    'Remind me later',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog() async {
    try {
      final response = await PatientApiService.getNotifications();
      final notifications = response['notifications'] as List? ?? [];
      final total = response['count'] ?? notifications.length;

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.notifications, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              Text('Notifications (${total})'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: notifications.isNotEmpty
                ? ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final isRead = notification['is_read'] ?? false;
                      IconData icon;

                      switch (notification['type']) {
                        case 'urgent':
                          icon = Icons.warning;
                          break;
                        case 'info':
                          icon = Icons.info;
                          break;
                        case 'success':
                          icon = Icons.check_circle;
                          break;
                        default:
                          icon = Icons.notifications;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            icon,
                            color: isRead ? Colors.grey : AppTheme.primaryBlue,
                          ),
                          title: SelectableText(
                            notification['title'] ?? 'Notification',
                            style: TextStyle(
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(notification['message'] ?? ''),
                              const SizedBox(height: 4),
                              Text(
                                notification['created_at'] != null
                                    ? _formatDate(notification['created_at'])
                                    : '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          trailing: !isRead
                              ? IconButton(
                                  icon: const Icon(Icons.mark_email_read),
                                  onPressed: () async {
                                    try {
                                      await ApiService.put(
                                        '${ApiConfig.patientNotifications}/${notification['_id']}/read',
                                        {},
                                      );
                                      setState(() {
                                        notifications[index]['is_read'] = true;
                                      });
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to mark as read: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                )
                              : null,
                          onTap: !isRead
                              ? () async {
                                  try {
                                    await ApiService.put(
                                      '${ApiConfig.patientNotifications}/${notification['_id']}/read',
                                      {},
                                    );
                                    setState(() {
                                      notifications[index]['is_read'] = true;
                                    });
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to mark as read: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              : null,
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No notifications found',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load notifications: $e')),
        );
      }
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }
}
