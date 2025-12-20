// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../utils/page_title_helper.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/owner_auth_provider.dart';
import '../../services/owner_api_service.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_dialog.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/system_feedback_form.dart';
import '../../utils/responsive_utils.dart' as app_responsive;
import 'owner_sidebar.dart';
import 'owner_profile_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  final int? initialTab;

  const OwnerDashboardScreen({super.key, this.initialTab});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _tests = [];
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _orders = [];

  // Reports data
  Map<String, dynamic>? _reportsData;
  bool _isLoadingReports = false; // Financial reports loading state

  // Error states
  String? _ordersError;

  // Sidebar state
  bool _isSidebarOpen = true;

  // Auth loading state
  bool _isAuthLoading = true;

  // Feedback tracking
  bool _hasFeedbackSubmitted = false;
  bool _showFeedbackReminder = true;

  // Search and filter controllers for orders
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;

  // Search controllers for staff and doctors
  final TextEditingController _staffSearchController = TextEditingController();
  final TextEditingController _doctorSearchController = TextEditingController();

  // Search controllers for tests and devices
  final TextEditingController _testSearchController = TextEditingController();
  final TextEditingController _deviceSearchController = TextEditingController();

  final List<String> _menuItems = [
    'Dashboard',
    'Staff',
    'Doctors',
    'Orders',
    'Tests',
    'Devices',
    'Inventory',
    'Reports',
    'Audit Logs',
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard,
    Icons.people,
    Icons.medical_services,
    Icons.assignment,
    Icons.science,
    Icons.devices,
    Icons.inventory,
    Icons.analytics,
    Icons.history,
  ];

  @override
  void initState() {
    super.initState();
    PageTitleHelper.updateTitle('Owner Dashboard - MedLab System');
    _selectedIndex = widget.initialTab ?? 0;
    _initializeAuthAndDashboard();
  }

  Future<void> _checkFeedbackStatus() async {
    try {
      final response = await OwnerApiService.getMyFeedback();
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

  Future<void> _initializeAuthAndDashboard() async {
    // Ensure auth state is loaded
    final authProvider = Provider.of<OwnerAuthProvider>(context, listen: false);
    await authProvider.loadAuthState();

    if (mounted) {
      setState(() => _isAuthLoading = false);

      // Only load dashboard if authenticated
      if (authProvider.isAuthenticated) {
        _loadDashboard();
        _checkFeedbackStatus();
      }
    }
  }

  Future<void> _loadStaff() async {
    try {
      final response = await OwnerApiService.getStaff();
      if (response['staff'] != null) {
        setState(() {
          _staff = List<Map<String, dynamic>>.from(response['staff']);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading staff: $e')));
      }
    }
  }

  Future<void> _loadDoctors() async {
    try {
      final response = await OwnerApiService.getDoctors();
      if (response['doctors'] != null) {
        setState(() {
          _doctors = List<Map<String, dynamic>>.from(response['doctors']);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading doctors: $e')));
      }
    }
  }

  Future<void> _loadTests() async {
    try {
      final response = await OwnerApiService.getTests();
      if (response['tests'] != null) {
        setState(() {
          _tests = List<Map<String, dynamic>>.from(response['tests']);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading tests: $e')));
      }
    }
  }

  Future<void> _loadDevices() async {
    try {
      final response = await OwnerApiService.getDevices();
      if (response['devices'] != null) {
        setState(() {
          _devices = List<Map<String, dynamic>>.from(response['devices']);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading devices: $e')));
      }
    }
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      // Only load dashboard statistics initially - no background loading
      final dashboardResponse = await OwnerApiService.getDashboard();
      if (mounted) {
        setState(() {
          _dashboardData = dashboardResponse;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('Dashboard loading error: $e');
        // Don't show error snackbar for now to avoid confusion
        // The dashboard will still show with empty data
      }
    }
  }

  // Background loading methods to avoid overwhelming the server
  Future<void> _loadStaffInBackground() async {
    if (_staff.isNotEmpty || !mounted) {
      return; // Already loaded or widget disposed
    }
    try {
      await Future.delayed(
        const Duration(milliseconds: 1600),
      ); // Increased delay
      if (!mounted) return; // Check again after delay
      final response = await OwnerApiService.getStaff();
      if (mounted) {
        setState(() {
          _staff = response['staff'] != null
              ? List<Map<String, dynamic>>.from(response['staff'])
              : [];
        });
      }
    } catch (e) {
      debugPrint('Background staff loading failed: $e');
    }
  }

  Future<void> _loadDoctorsInBackground() async {
    if (_doctors.isNotEmpty || !mounted) {
      return; // Already loaded or widget disposed
    }
    try {
      await Future.delayed(
        const Duration(milliseconds: 2400),
      ); // Increased delay
      if (!mounted) return; // Check again after delay
      final response = await OwnerApiService.getDoctors();
      if (mounted) {
        setState(() {
          _doctors = response['doctors'] != null
              ? List<Map<String, dynamic>>.from(response['doctors'])
              : [];
        });
      }
    } catch (e) {
      debugPrint('Background doctors loading failed: $e');
    }
  }

  Future<void> _loadTestsInBackground() async {
    if (_tests.isNotEmpty || !mounted) {
      return; // Already loaded or widget disposed
    }
    try {
      await Future.delayed(
        const Duration(milliseconds: 3200),
      ); // Increased delay
      if (!mounted) return; // Check again after delay
      final response = await OwnerApiService.getTests();
      if (mounted) {
        setState(() {
          _tests = response['tests'] != null
              ? List<Map<String, dynamic>>.from(response['tests'])
              : [];
        });
      }
    } catch (e) {
      debugPrint('Background tests loading failed: $e');
    }
  }

  Future<void> _loadDevicesInBackground() async {
    if (_devices.isNotEmpty || !mounted) {
      return; // Already loaded or widget disposed
    }
    try {
      await Future.delayed(
        const Duration(milliseconds: 4000),
      ); // Increased delay
      if (!mounted) return; // Check again after delay
      final response = await OwnerApiService.getDevices();
      if (response['devices'] != null && mounted) {
        setState(() {
          _devices = List<Map<String, dynamic>>.from(response['devices']);
        });
      }
    } catch (e) {
      debugPrint('Background devices loading failed: $e');
      debugPrint('Background devices loading failed: $e');
    }
  }

  void _toggleSidebar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final canShowSidebar =
        !ResponsiveBreakpoints.of(context).isMobile && screenWidth > 600;

    if (_isSidebarOpen || canShowSidebar) {
      setState(() => _isSidebarOpen = !_isSidebarOpen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<OwnerAuthProvider>(context);
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final screenWidth = MediaQuery.of(context).size.width;

    // Show loading while auth state is being determined
    if (_isAuthLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading...'),
            ],
          ),
        ),
      );
    }

    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Open menu',
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  app_responsive.ResponsiveText(
                    'Lab Owner Dashboard',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  app_responsive.ResponsiveText(
                    'Welcome back, ${authProvider.user?.fullName?.first ?? 'Owner'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            )
          : AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              leading: IconButton(
                icon: AnimatedIcon(
                  icon: AnimatedIcons.menu_close,
                  progress: _isSidebarOpen
                      ? const AlwaysStoppedAnimation(1.0)
                      : const AlwaysStoppedAnimation(0.0),
                ),
                onPressed: _toggleSidebar,
                tooltip: _isSidebarOpen ? 'Close sidebar' : 'Open sidebar',
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  app_responsive.ResponsiveText(
                    'Lab Owner Dashboard',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  app_responsive.ResponsiveText(
                    'Welcome back, ${authProvider.user?.fullName?.first ?? 'Owner'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              actions: [
                Container(
                  padding: app_responsive.ResponsiveUtils.getResponsivePadding(
                    context,
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.business,
                        color: AppTheme.primaryBlue,
                        size: app_responsive
                            .ResponsiveUtils.getResponsiveIconSize(context, 20),
                      ),
                      SizedBox(
                        width: app_responsive
                            .ResponsiveUtils.getResponsiveSpacing(context, 8),
                      ),
                      app_responsive.ResponsiveText(
                        'Lab Owner',
                        style: TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
      drawer: isMobile
          ? Builder(
              builder: (context) {
                return AppAnimations.slideInFromLeft(_buildDrawer());
              },
            )
          : null,
      body: Stack(
        children: [
          Row(
            children: [
              if (!isMobile && _isSidebarOpen && screenWidth > 600)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 280,
                  child: OwnerSidebar(
                    selectedIndex: _selectedIndex,
                    onItemSelected: (index) {
                      setState(() => _selectedIndex = index);
                    },
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? AppAnimations.pulse(
                        const Center(child: CircularProgressIndicator()),
                      )
                    : AppAnimations.fadeIn(
                        _buildDashboardContent(),
                        delay: 300.ms,
                      ),
              ),
            ],
          ),
          // Screen Width Display
          Positioned(
            top: isMobile ? 10 : 70,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Width: ${screenWidth.toStringAsFixed(0)}px',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildSpeedDial(),
    );
  }

  Widget _buildSpeedDial() {
    return FloatingActionButton(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => Container(
            padding: app_responsive.ResponsiveUtils.getResponsivePadding(
              context,
              horizontal: 20,
              vertical: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(
                    bottom: app_responsive.ResponsiveUtils.getResponsiveSpacing(
                      context,
                      20,
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.support_agent, color: Colors.blue),
                  ),
                  title: const Text('Contact Admin'),
                  subtitle: const Text('Send a message to system admin'),
                  onTap: () {
                    Navigator.pop(context);
                    _showContactAdminDialog();
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
      tooltip: 'Quick Actions',
      child: const Icon(Icons.add),
    );
  }

  void _showContactAdminDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.support_agent, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Contact Admin', style: TextStyle(fontSize: 20)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Send a message to the system administrator',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'Enter message subject',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title),
                  ),
                  enabled: !isSubmitting,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Enter your message',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.message),
                  ),
                  maxLines: 5,
                  enabled: !isSubmitting,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () {
                      Navigator.pop(context);
                    },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a subject'),
                          ),
                        );
                        return;
                      }

                      if (messageController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a message'),
                          ),
                        );
                        return;
                      }

                      setState(() => isSubmitting = true);

                      try {
                        await OwnerApiService.contactAdmin(
                          title: titleController.text.trim(),
                          message: messageController.text.trim(),
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '✅ Message sent successfully to admin',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to send message: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } finally {
                        setState(() => isSubmitting = false);
                      }
                    },
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(isSubmitting ? 'Sending...' : 'Send Message'),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Dispose controllers when dialog is completely closed
      titleController.dispose();
      messageController.dispose();
    });
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => SystemFeedbackForm(
        onSubmit: (feedbackData) async {
          try {
            await OwnerApiService.provideFeedback(
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
                    'Help us improve by sharing your feedback',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showFeedbackDialog(),
                    icon: const Icon(Icons.rate_review, size: 18),
                    label: const Text('Feedback'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
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
                    child: const Text('Later', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: AppTheme.cardColor,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
              child: Column(
                children: [
                  const Icon(Icons.business, size: 48, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    'Lab Owner',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: List.generate(_menuItems.length, (index) {
                  final isSelected = _selectedIndex == index;
                  return AnimatedCard(
                    onTap: () => setState(() => _selectedIndex = index),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: Icon(
                          _menuIcons[index],
                          color: isSelected
                              ? AppTheme.primaryBlue
                              : AppTheme.textLight,
                        ),
                        title: Text(
                          _menuItems[index],
                          style: TextStyle(
                            color: isSelected
                                ? AppTheme.primaryBlue
                                : AppTheme.textDark,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        selectedTileColor: AppTheme.primaryBlue.withValues(
                          alpha: 0.1,
                        ),
                        onTap: () {
                          setState(() => _selectedIndex = index);
                          Navigator.pop(context); // Close drawer
                        },
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardView();
      case 1:
        // Load staff when navigating to staff tab
        if (_staff.isEmpty) {
          _loadStaffInBackground();
        }
        return _buildStaffView();
      case 2:
        // Load doctors when navigating to doctors tab
        if (_doctors.isEmpty) {
          _loadDoctorsInBackground();
        }
        return _buildDoctorsView();
      case 3:
        // Load orders when navigating to orders tab
        if (_orders.isEmpty) {
          _loadOrdersInBackground();
        }
        return _buildOrdersView();
      case 4:
        // Load tests when navigating to tests tab
        if (_tests.isEmpty) {
          _loadTestsInBackground();
        }
        return _buildTestsView();
      case 5:
        // Load devices when navigating to devices tab
        if (_devices.isEmpty) {
          _loadDevicesInBackground();
        }
        return _buildDevicesView();
      case 6:
        return _buildInventoryView();
      case 7:
        return _buildAuditLogsView();
      case 8:
        return const OwnerProfileScreen();
      default:
        return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = ResponsiveBreakpoints.of(context).isMobile;
          final screenWidth = MediaQuery.of(context).size.width;
          final isVerySmall = screenWidth < 500;

          return SingleChildScrollView(
            child: Column(
              children: [
                if (_showFeedbackReminder)
                  Padding(
                    padding:
                        app_responsive.ResponsiveUtils.getResponsivePadding(
                          context,
                          horizontal: 16,
                          vertical: 16,
                        ),
                    child: AppAnimations.elasticSlideIn(
                      _buildFeedbackReminderBanner(),
                      delay: 50.ms,
                    ),
                  ),
                // Hero Section
                AppAnimations.blurFadeIn(
                  _buildHeroSection(
                    context,
                    constraints,
                    isMobile,
                    isVerySmall,
                  ),
                ),
                // Stats Section
                AppAnimations.elasticSlideIn(
                  _buildStatsSection(
                    context,
                    constraints,
                    isMobile,
                    isVerySmall,
                  ),
                  delay: 200.ms,
                ),
                // Charts Section
                AppAnimations.elasticSlideIn(
                  _buildChartsSection(
                    context,
                    constraints,
                    isMobile,
                    isVerySmall,
                  ),
                  delay: 400.ms,
                ),
                // Activity Section
                AppAnimations.elasticSlideIn(
                  _buildActivitySection(context, isMobile, isVerySmall),
                  delay: 600.ms,
                ),
                // Quick Actions Section
                AppAnimations.elasticSlideIn(
                  _buildQuickActionsSection(context, isMobile, isVerySmall),
                  delay: 800.ms,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroSection(
    BuildContext context,
    BoxConstraints constraints,
    bool isMobile,
    bool isVerySmall,
  ) {
    final orders = _dashboardData?['orders'] ?? {};
    final financials = _dashboardData?['financials'] ?? {};

    final totalRevenue = financials['monthlyRevenue'] ?? 0;
    final totalOrders = orders['total'] ?? 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
      padding: EdgeInsets.only(
        left: isMobile ? 24 : 48,
        right: isMobile ? 24 : 48,
        top: isVerySmall ? 48 : (isMobile ? 80 : 120),
        bottom: isVerySmall ? 48 : (isMobile ? 80 : 120),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAnimations.liquidMorph(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAnimations.rotateIn(
                  Icon(
                    Icons.business,
                    size: isVerySmall ? 40 : (isMobile ? 48 : 64),
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  delay: 200.ms,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppAnimations.typingEffect(
                        'Welcome to Your Lab Dashboard',
                        Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: Colors.white,
                              fontSize: isVerySmall ? 24 : (isMobile ? 32 : 42),
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ) ??
                            const TextStyle(),
                      ),
                      const SizedBox(height: 8),
                      AppAnimations.fadeIn(
                        Text(
                          'Manage your laboratory operations efficiently with real-time insights',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: isVerySmall
                                    ? 12
                                    : (isMobile ? 16 : 20),
                                height: 1.4,
                              ),
                          softWrap: true,
                        ),
                        delay: 800.ms,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          AppAnimations.elasticSlideIn(
            Wrap(
              spacing: isMobile ? 16 : 20,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                AppAnimations.glowPulse(
                  _buildEnhancedHeroMetric(
                    'Monthly Revenue',
                    '\$${totalRevenue.toStringAsFixed(2)}',
                    Icons.attach_money,
                    AppTheme.successGreen,
                    constraints,
                    isMobile,
                    isVerySmall,
                  ),
                  glowColor: AppTheme.successGreen,
                ),
                AppAnimations.glowPulse(
                  _buildEnhancedHeroMetric(
                    'Total Orders',
                    totalOrders.toString(),
                    Icons.shopping_cart,
                    AppTheme.primaryBlue,
                    constraints,
                    isMobile,
                    isVerySmall,
                  ),
                  glowColor: AppTheme.primaryBlue,
                ),
              ],
            ),
            delay: 600.ms,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedHeroMetric(
    String label,
    String value,
    IconData icon,
    Color color,
    BoxConstraints constraints,
    bool isMobile,
    bool isVerySmall,
  ) {
    return Container(
      width: isMobile ? double.infinity : (isVerySmall ? 200 : 240),
      padding: EdgeInsets.all(isVerySmall ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isVerySmall ? 12 : 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isVerySmall ? 24 : 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    BoxConstraints constraints,
    bool isMobile,
    bool isVerySmall,
  ) {
    final resources = _dashboardData?['resources'] ?? {};
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine cross axis count based on screen size
    // Mobile (< 600px): 1 column
    // Tablet (600px - 1024px): 2 columns
    // Desktop (> 1024px): 2 columns
    final crossAxisCount = screenWidth < 600 ? 1 : 2;

    final stats = [
      {
        'title': 'Total Staff',
        'value': _staff.isNotEmpty
            ? _staff.length.toString()
            : (resources['staff']?.toString() ?? '0'),
        'change': '${resources['staff'] ?? 0} members',
        'icon': Icons.people,
        'color': AppTheme.secondaryTeal,
        'description': 'Your team members',
      },
      {
        'title': 'Total Patients',
        'value': resources['patients']?.toString() ?? '0',
        'change': '${resources['patients'] ?? 0} registered',
        'icon': Icons.person,
        'color': AppTheme.errorRed,
        'description': 'Patient records',
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isVerySmall ? 40 : (isMobile ? 60 : 100),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              isVerySmall ? 'System Overview' : 'System Overview & Statistics',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isVerySmall ? 20 : (isMobile ? 28 : 36),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isVerySmall ? 40 : 60),
          AnimatedGridView(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            padding: EdgeInsets.zero,
            children: stats.map((stat) {
              return AnimatedCard(
                child: Padding(
                  padding: EdgeInsets.all(isVerySmall ? 20 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (stat['color'] as Color).withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              stat['icon'] as IconData,
                              color: stat['color'] as Color,
                              size: isVerySmall ? 24 : 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stat['title'] as String,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: isVerySmall ? 16 : null,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    stat['change'] as String,
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: isVerySmall ? 10 : 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SelectableText(
                        stat['value'] as String,
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: stat['color'] as Color,
                              fontSize: isVerySmall ? 24 : null,
                            ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        stat['description'] as String,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                          fontSize: isVerySmall ? 12 : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = ResponsiveBreakpoints.of(context).isMobile;
        final screenWidth = MediaQuery.of(context).size.width;
        final isVerySmall = screenWidth < 500;

        return RefreshIndicator(
          onRefresh: () async {
            if (_orders.isEmpty) {
              await _loadOrdersInBackground();
            }
          },
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppAnimations.fadeIn(
                  Text(
                    'Order Management',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: isVerySmall ? 24 : (isMobile ? 32 : 40),
                    ),
                  ),
                ),
                SizedBox(height: isVerySmall ? 20 : 32),

                // Orders List
                ...(_ordersError != null
                    ? [
                        AppAnimations.fadeIn(
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: AppTheme.errorRed,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Failed to load orders',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _ordersError!,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  onPressed: _loadOrdersInBackground,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]
                    : _orders.isEmpty
                    ? [
                        AppAnimations.fadeIn(
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No orders found',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Orders will appear here once patients place them.',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(color: Colors.grey[600]),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ]
                    : [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            return AppAnimations.slideInFromRight(
                              _buildOrderCardWithInvoice(order),
                              delay: Duration(milliseconds: 50 * index),
                            );
                          },
                        ),
                      ]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderCardWithInvoice(dynamic order) {
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
            const SizedBox(height: 16),
            // Patient & Doctor Info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Patient',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        order['patient_name'] ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.medical_services,
                            size: 14,
                            color: Colors.green[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Doctor',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        order['doctor_name'] ?? 'Not Assigned',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: order['doctor_name'] != null
                              ? AppTheme.textDark
                              : Colors.grey[500],
                          fontStyle: order['doctor_name'] != null
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (order['order_details'] != null &&
                order['order_details'].isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Tests & Assigned Staff:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              ..._buildTestListWithStaff(order['order_details']),
            ],
            const SizedBox(height: 20),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showOrderDetailsWithInvoice(order),
                    icon: const Icon(Icons.science, size: 18),
                    label: const Text('View Details'),
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
                    onPressed: () => _showInvoiceDetails(order),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('View Invoice'),
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

  List<Widget> _buildTestListWithStaff(List<dynamic> orderDetails) {
    return orderDetails.take(5).map((detail) {
      final testName = detail['test_name'] ?? 'Unknown Test';
      final assignedStaff = detail['staff_id'];
      final staffName = assignedStaff != null
          ? '${assignedStaff['full_name']?['first'] ?? ''} ${assignedStaff['full_name']?['last'] ?? ''}'
                .trim()
          : 'Unassigned';

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.science, size: 16, color: AppTheme.primaryBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                testName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: assignedStaff != null
                    ? AppTheme.successGreen.withValues(alpha: 0.1)
                    : AppTheme.warningYellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                assignedStaff != null ? 'Assigned' : 'Unassigned',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: assignedStaff != null
                      ? AppTheme.successGreen
                      : AppTheme.warningYellow,
                ),
              ),
            ),
            if (assignedStaff != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.person, size: 14, color: AppTheme.primaryBlue),
              const SizedBox(width: 4),
              Text(
                staffName,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  void _showOrderDetailsWithInvoice(dynamic order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Order #${order['_id']?.toString().substring(0, 8) ?? 'N/A'}',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Patient', order['patient_name'] ?? 'N/A'),
              _buildDetailRow('Doctor', order['doctor_name'] ?? 'Not Assigned'),
              _buildDetailRow(
                'Status',
                _getStatusText(order['status'] ?? 'pending'),
              ),
              _buildDetailRow(
                'Order Date',
                order['order_date'] != null
                    ? DateTime.parse(
                        order['order_date'],
                      ).toString().split(' ')[0]
                    : 'N/A',
              ),
              _buildDetailRow('Test Count', '${order['test_count'] ?? 0}'),
              if (order['total_cost'] != null)
                _buildDetailRow(
                  'Total Cost',
                  'ILS ${order['total_cost'].toStringAsFixed(2)}',
                ),
              if (order['barcode'] != null)
                _buildDetailRow('Barcode', order['barcode'].toString()),
              const SizedBox(height: 16),
              const Text(
                'Test Details:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._buildDetailedTestList(order['order_details'] ?? []),
            ],
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
  }

  void _showInvoiceDetails(dynamic order) {
    // For now, show a placeholder. In a real implementation, this would
    // navigate to or show invoice details
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invoice Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order ID: ${order['_id']?.toString().substring(0, 8) ?? 'N/A'}',
            ),
            const SizedBox(height: 8),
            Text('Patient: ${order['patient_name'] ?? 'N/A'}'),
            const SizedBox(height: 8),
            Text(
              'Total Amount: ILS ${order['total_cost']?.toStringAsFixed(2) ?? 'N/A'}',
            ),
            const SizedBox(height: 8),
            Text('Status: ${order['status'] ?? 'Unknown'}'),
            const SizedBox(height: 16),
            const Text(
              'Invoice functionality coming soon...',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDetailedTestList(List<dynamic> orderDetails) {
    return orderDetails.map((detail) {
      final testName = detail['test_name'] ?? 'Unknown Test';
      final assignedStaff = detail['staff_id'];
      final staffName = assignedStaff != null
          ? '${assignedStaff['full_name']?['first'] ?? ''} ${assignedStaff['full_name']?['last'] ?? ''}'
                .trim()
          : 'Unassigned';

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              testName,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 14,
                  color: assignedStaff != null
                      ? AppTheme.primaryBlue
                      : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  'Staff: $staffName',
                  style: TextStyle(
                    fontSize: 12,
                    color: assignedStaff != null
                        ? AppTheme.primaryBlue
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(
    BuildContext context,
    BoxConstraints constraints,
    bool isMobile,
    bool isVerySmall,
  ) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isVerySmall ? 40 : (isMobile ? 60 : 100),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              isVerySmall ? 'Revenue Analytics' : 'Revenue Analytics & Trends',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isVerySmall ? 20 : (isMobile ? 28 : 36),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isVerySmall ? 40 : 60),
          AnimatedCard(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.analytics,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Revenue Overview',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            SelectableText(
                              'Revenue from lab operations and test services',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: isVerySmall ? 200 : 250,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: 5,
                        minY: 0,
                        maxY: 8,
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              const FlSpot(0, 3),
                              const FlSpot(1, 4),
                              const FlSpot(2, 3.5),
                              const FlSpot(3, 5),
                              const FlSpot(4, 4.5),
                              const FlSpot(5, 6),
                            ],
                            isCurved: true,
                            color: Theme.of(context).colorScheme.primary,
                            barWidth: 4,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    final notifications = _dashboardData?['notifications']?['recent'] ?? [];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isVerySmall ? 40 : (isMobile ? 60 : 100),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              isVerySmall ? 'Recent Activity' : 'Recent Activity & Updates',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isVerySmall ? 20 : (isMobile ? 28 : 36),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isVerySmall ? 40 : 60),
          AnimatedCard(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Activity Feed',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            SelectableText(
                              'Recent updates and notifications',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (notifications.isEmpty)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 48,
                            color: AppTheme.textLight,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No recent activity',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: AppTheme.textLight),
                          ),
                        ],
                      ),
                    )
                  else
                    ...notifications
                        .take(5)
                        .map(
                          (notification) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.info,
                                    color: AppTheme.primaryBlue,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        notification['title'] ?? 'Activity',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                        softWrap: true,
                                      ),
                                      const SizedBox(height: 4),
                                      SelectableText(
                                        notification['message'] ?? '',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: Colors.grey[600]),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notification['createdAt'] != null
                                            ? DateTime.parse(
                                                notification['createdAt'],
                                              ).toString().split(' ')[0]
                                            : '',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine cross axis count based on screen size
    // Mobile (< 600px): 1 column
    // Tablet (600px - 1024px): 2 columns
    // Desktop (> 1024px): 2 columns
    final crossAxisCount = screenWidth < 600 ? 1 : 2;

    final actions = [
      {
        'title': 'Add Staff',
        'subtitle': 'Hire and manage laboratory staff',
        'icon': Icons.person_add,
        'color': AppTheme.secondaryTeal,
        'onTap': () => _showStaffDialog(),
      },
      {
        'title': 'Add Test',
        'subtitle': 'Configure new laboratory tests',
        'icon': Icons.add_circle,
        'color': AppTheme.accentOrange,
        'onTap': () => _showTestDialog(),
      },
      {
        'title': 'Manage Inventory',
        'subtitle': 'Track and manage lab supplies',
        'icon': Icons.inventory,
        'color': AppTheme.primaryBlue,
        'onTap': () => setState(() => _selectedIndex = 6),
      },
      {
        'title': 'Manage Orders',
        'subtitle': 'View and process test orders',
        'icon': Icons.assignment,
        'color': AppTheme.secondaryTeal,
        'onTap': () => setState(() => _selectedIndex = 3),
      },
      {
        'title': 'View Reports',
        'subtitle': 'Access detailed analytics and reports',
        'icon': Icons.analytics,
        'color': AppTheme.successGreen,
        'onTap': () => setState(() => _selectedIndex = 7),
      },
    ];

    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isVerySmall ? 40 : (isMobile ? 60 : 100),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              isVerySmall ? 'Quick Actions' : 'Quick Actions & Management',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isVerySmall ? 20 : (isMobile ? 28 : 36),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isVerySmall ? 40 : 60),
          AnimatedGridView(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            padding: EdgeInsets.zero,
            children: actions.map((action) {
              return AnimatedCard(
                onTap: action['onTap'] as VoidCallback,
                child: Padding(
                  padding: EdgeInsets.all(isVerySmall ? 20 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (action['color'] as Color).withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          action['icon'] as IconData,
                          color: action['color'] as Color,
                          size: isVerySmall ? 24 : 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        action['title'] as String,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isVerySmall ? 16 : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action['subtitle'] as String,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                          fontSize: isVerySmall ? 12 : null,
                        ),
                        softWrap: true,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Access Now',
                              style: TextStyle(
                                color: action['color'] as Color,
                                fontWeight: FontWeight.bold,
                                fontSize: isVerySmall ? 12 : 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            color: action['color'] as Color,
                            size: isVerySmall ? 14 : 16,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffView() {
    // Filter staff based on search query
    final filteredStaff = _staff.where((staff) {
      if (_staffSearchController.text.isEmpty) return true;
      final searchLower = _staffSearchController.text.toLowerCase();
      final fullName =
          '${staff['full_name']?['first'] ?? ''} ${staff['full_name']?['last'] ?? ''}'
              .toLowerCase();
      final employeeNumber = (staff['employee_number'] ?? '')
          .toString()
          .toLowerCase();
      final role = (staff['role'] ?? '').toString().toLowerCase();
      final email = (staff['email'] ?? '').toString().toLowerCase();

      return fullName.contains(searchLower) ||
          employeeNumber.contains(searchLower) ||
          role.contains(searchLower) ||
          email.contains(searchLower);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total Staff: ${_staff.isNotEmpty ? _staff.length : (_dashboardData?['resources']?['staff'] ?? 0)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Staff'),
                    onPressed: () => _showStaffDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _staffSearchController,
                decoration: InputDecoration(
                  hintText:
                      'Search by name, employee number, role, or email...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _staffSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _staffSearchController.clear();
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: (value) => setState(() {}),
              ),
              if (_staffSearchController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Found: ${filteredStaff.length} staff member(s)',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: filteredStaff.isEmpty
              ? Center(
                  child: Text(
                    _staffSearchController.text.isNotEmpty
                        ? 'No staff found matching "${_staffSearchController.text}"'
                        : 'No staff found. Add your first staff member!',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredStaff.length,
                  itemBuilder: (context, index) {
                    final staff = filteredStaff[index];
                    return _buildStaffCard(staff);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff) {
    final fullName =
        '${staff['full_name']?['first'] ?? ''} ${staff['full_name']?['middle'] != null && staff['full_name']?['middle'].isNotEmpty ? '${staff['full_name']?['middle']} ' : ''}${staff['full_name']?['last'] ?? ''}';

    return _StaffCardExpanded(
      staff: staff,
      fullName: fullName,
      onEdit: () => _showStaffDialog(staff),
      onDelete: () => _deleteStaff(staff['_id']),
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    final fullName =
        '${doctor['name']?['first'] ?? ''} ${doctor['name']?['last'] ?? ''}';

    return _DoctorCardExpanded(
      doctor: doctor,
      fullName: fullName,
      onEdit: () => _showDoctorDialog(doctor),
      onDelete: () => _deleteDoctor(doctor['_id']),
    );
  }

  Widget _buildTestCard(Map<String, dynamic> test) {
    return _TestCardExpanded(
      test: test,
      onEdit: () => _showTestDialog(test),
      onDelete: () => _deleteTest(test['_id']),
      onComponents: () => _showComponentsDialog(test),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    return _DeviceCardExpanded(
      device: device,
      onEdit: () => _showDeviceDialog(device),
      onDelete: () => _deleteDevice(device['_id']),
    );
  }

  Widget _buildDoctorsView() {
    // Filter doctors based on search query
    final filteredDoctors = _doctors.where((doctor) {
      if (_doctorSearchController.text.isEmpty) return true;
      final searchLower = _doctorSearchController.text.toLowerCase();
      final fullName =
          '${doctor['name']?['first'] ?? ''} ${doctor['name']?['last'] ?? ''}'
              .toLowerCase();
      final email = (doctor['email'] ?? '').toString().toLowerCase();

      return fullName.contains(searchLower) || email.contains(searchLower);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total Doctors: ${_doctors.length}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Doctor'),
                    onPressed: () => _showDoctorDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _doctorSearchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _doctorSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _doctorSearchController.clear();
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: (value) => setState(() {}),
              ),
              if (_doctorSearchController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Found: ${filteredDoctors.length} doctor(s)',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: filteredDoctors.isEmpty
              ? Center(
                  child: Text(
                    _doctorSearchController.text.isNotEmpty
                        ? 'No doctors found matching "${_doctorSearchController.text}"'
                        : 'No doctors found. Add your first doctor!',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDoctors.length,
                  itemBuilder: (context, index) {
                    final doctor = filteredDoctors[index];
                    return _buildDoctorCard(doctor);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTestsView() {
    // Filter tests based on search query
    final filteredTests = _tests.where((test) {
      if (_testSearchController.text.isEmpty) return true;
      final searchLower = _testSearchController.text.toLowerCase();
      final testName = (test['test_name'] ?? '').toString().toLowerCase();
      final testCode = (test['test_code'] ?? '').toString().toLowerCase();
      final price = (test['price'] ?? '').toString().toLowerCase();
      final category = (test['category'] ?? '').toString().toLowerCase();

      return testName.contains(searchLower) ||
          testCode.contains(searchLower) ||
          price.contains(searchLower) ||
          category.contains(searchLower);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total Tests: ${_tests.isNotEmpty ? _tests.length : (_dashboardData?['resources']?['tests'] ?? 0)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Test'),
                    onPressed: () => _showTestDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _testSearchController,
                decoration: InputDecoration(
                  hintText: 'Search by test name, code, price, or category...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _testSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _testSearchController.clear();
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: (value) => setState(() {}),
              ),
              if (_testSearchController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Found: ${filteredTests.length} test(s)',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: filteredTests.isEmpty
              ? Center(
                  child: Text(
                    _testSearchController.text.isNotEmpty
                        ? 'No tests found matching "${_testSearchController.text}"'
                        : 'No tests found. Add your first test!',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTests.length,
                  itemBuilder: (context, index) {
                    final test = filteredTests[index];
                    return _buildTestCard(test);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDevicesView() {
    // Filter devices based on search query
    final filteredDevices = _devices.where((device) {
      if (_deviceSearchController.text.isEmpty) return true;
      final searchLower = _deviceSearchController.text.toLowerCase();
      final name = (device['name'] ?? '').toString().toLowerCase();
      final serialNumber = (device['serial_number'] ?? '')
          .toString()
          .toLowerCase();
      final model = (device['model'] ?? '').toString().toLowerCase();
      final manufacturer = (device['manufacturer'] ?? '')
          .toString()
          .toLowerCase();

      return name.contains(searchLower) ||
          serialNumber.contains(searchLower) ||
          model.contains(searchLower) ||
          manufacturer.contains(searchLower);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total Devices: ${_devices.isNotEmpty ? _devices.length : (_dashboardData?['resources']?['devices'] ?? 0)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Device'),
                    onPressed: () => _showDeviceDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _deviceSearchController,
                decoration: InputDecoration(
                  hintText:
                      'Search by name, serial number, model, or manufacturer...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _deviceSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _deviceSearchController.clear();
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: (value) => setState(() {}),
              ),
              if (_deviceSearchController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Found: ${filteredDevices.length} device(s)',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: filteredDevices.isEmpty
              ? Center(
                  child: Text(
                    _deviceSearchController.text.isNotEmpty
                        ? 'No devices found matching "${_deviceSearchController.text}"'
                        : 'No devices found. Add your first device!',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDevices.length,
                  itemBuilder: (context, index) {
                    final device = filteredDevices[index];
                    return _buildDeviceCard(device);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInventoryView() {
    // Display inventory management content directly in the dashboard
    return _InventoryManagementWidget();
  }

  Widget _buildReportsView() {
    // Load reports data if not already loaded
    if (_reportsData == null && !_isLoadingReports) {
      _loadReportsData();
    }

    if (_isLoadingReports) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reportsData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Failed to load reports data'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReportsData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Extract financial data
    final revenueData = _reportsData?['revenue'];
    final revenue = revenueData is Map
        ? (revenueData['total'] ?? 0)
        : (_dashboardData?['financials']?['monthlyRevenue'] ?? 0);
    final expenses = _reportsData?['expenses'] ?? {};
    final subscriptionExpenses = expenses['subscriptions'] ?? 0;
    final inventoryExpenses = expenses['inventory'] ?? 0;
    final salaryExpenses = expenses['salaries'] ?? 0;
    final totalExpenses =
        subscriptionExpenses + inventoryExpenses + salaryExpenses;
    final profit = revenue - totalExpenses;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.analytics, size: 32, color: Colors.blue),
              const SizedBox(width: 16),
              Text(
                'Financial Reports',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildFinancialCard(
                  'Total Revenue',
                  '\$${revenue.toStringAsFixed(2)}',
                  Icons.trending_up,
                  Colors.green,
                  'From patient orders',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFinancialCard(
                  'Total Expenses',
                  '\$${totalExpenses.toStringAsFixed(2)}',
                  Icons.trending_down,
                  Colors.red,
                  'Subscriptions + Inventory + Salaries',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFinancialCard(
                  'Net Profit',
                  '\$${profit.toStringAsFixed(2)}',
                  profit >= 0 ? Icons.thumb_up : Icons.thumb_down,
                  profit >= 0 ? Colors.green : Colors.red,
                  profit >= 0 ? 'Positive cash flow' : 'Negative cash flow',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Charts Section
          Text(
            'Financial Overview',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Revenue vs Expenses Bar Chart
              Expanded(
                flex: 3,
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Revenue vs Expenses',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 300,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY:
                                  [
                                    revenue,
                                    totalExpenses,
                                  ].reduce((a, b) => a > b ? a : b) *
                                  1.2,
                              barTouchData: BarTouchData(
                                enabled: true,
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem:
                                      (group, groupIndex, rod, rodIndex) {
                                        return BarTooltipItem(
                                          '\$${rod.toY.toStringAsFixed(2)}',
                                          const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      },
                                ),
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      switch (value.toInt()) {
                                        case 0:
                                          return const Padding(
                                            padding: EdgeInsets.only(top: 8),
                                            child: Text(
                                              'Revenue',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        case 1:
                                          return const Padding(
                                            padding: EdgeInsets.only(top: 8),
                                            child: Text(
                                              'Expenses',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        default:
                                          return const Text('');
                                      }
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 60,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        '\$${value.toStringAsFixed(0)}',
                                        style: const TextStyle(fontSize: 10),
                                      );
                                    },
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval:
                                    (revenue > totalExpenses
                                        ? revenue
                                        : totalExpenses) /
                                    5,
                              ),
                              borderData: FlBorderData(show: false),
                              barGroups: [
                                BarChartGroupData(
                                  x: 0,
                                  barRods: [
                                    BarChartRodData(
                                      toY: revenue.toDouble(),
                                      color: Colors.green,
                                      width: 60,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                      ),
                                    ),
                                  ],
                                ),
                                BarChartGroupData(
                                  x: 1,
                                  barRods: [
                                    BarChartRodData(
                                      toY: totalExpenses.toDouble(),
                                      color: Colors.red,
                                      width: 60,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Expense Breakdown Pie Chart
              Expanded(
                flex: 2,
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expense Breakdown',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 250,
                          child: totalExpenses > 0
                              ? PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 50,
                                    sections: [
                                      PieChartSectionData(
                                        value: subscriptionExpenses.toDouble(),
                                        title:
                                            '${((subscriptionExpenses / totalExpenses) * 100).toStringAsFixed(1)}%',
                                        color: Colors.blue,
                                        radius: 70,
                                        titleStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      PieChartSectionData(
                                        value: inventoryExpenses.toDouble(),
                                        title:
                                            '${((inventoryExpenses / totalExpenses) * 100).toStringAsFixed(1)}%',
                                        color: Colors.orange,
                                        radius: 70,
                                        titleStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      PieChartSectionData(
                                        value: salaryExpenses.toDouble(),
                                        title:
                                            '${((salaryExpenses / totalExpenses) * 100).toStringAsFixed(1)}%',
                                        color: Colors.purple,
                                        radius: 70,
                                        titleStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const Center(child: Text('No expense data')),
                        ),
                        const SizedBox(height: 16),
                        // Legend
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem(
                              'Subscriptions',
                              Colors.blue,
                              subscriptionExpenses,
                            ),
                            const SizedBox(height: 8),
                            _buildLegendItem(
                              'Inventory',
                              Colors.orange,
                              inventoryExpenses,
                            ),
                            const SizedBox(height: 8),
                            _buildLegendItem(
                              'Salaries',
                              Colors.purple,
                              salaryExpenses,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Detailed Breakdown
          Text(
            'Detailed Expense Breakdown',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildExpenseRow('Subscriptions', subscriptionExpenses),
                  const Divider(),
                  _buildExpenseRow('Inventory', inventoryExpenses),
                  const Divider(),
                  _buildExpenseRow('Salaries', salaryExpenses),
                  const Divider(height: 32),
                  _buildExpenseRow(
                    'Total Expenses',
                    totalExpenses,
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Revenue Details
          Text(
            'Revenue Details',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Patient Orders',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Text(
                        '\$${revenue.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Revenue generated from completed patient test orders',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Refresh Button
          Center(
            child: ElevatedButton.icon(
              onPressed: _loadReportsData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Reports'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStaffDialog([Map<String, dynamic>? staff]) async {
    final firstNameController = TextEditingController(
      text: staff?['full_name']?['first'],
    );
    final middleNameController = TextEditingController(
      text: staff?['full_name']?['middle'],
    );
    final lastNameController = TextEditingController(
      text: staff?['full_name']?['last'],
    );
    final identityNumberController = TextEditingController(
      text: staff?['identity_number'],
    );
    final emailController = TextEditingController(text: staff?['email']);
    final phoneController = TextEditingController(
      text: staff?['phone_number'] ?? staff?['phone'],
    );
    final usernameController = TextEditingController(text: staff?['username']);
    final passwordController = TextEditingController();
    final employeeNumberController = TextEditingController(
      text: staff?['employee_number'],
    );
    final qualificationController = TextEditingController(
      text: staff?['qualification'],
    );
    final professionLicenseController = TextEditingController(
      text: staff?['profession_license'],
    );
    final salaryController = TextEditingController(
      text: staff?['salary']?.toString(),
    );
    final bankIbanController = TextEditingController(text: staff?['bank_iban']);

    DateTime? selectedBirthday = staff?['birthday'] != null
        ? DateTime.parse(staff!['birthday'])
        : null;
    String gender = staff?['gender'] ?? 'Male';
    String socialStatus = staff?['social_status'] ?? 'Single';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(staff == null ? 'Add Staff' : 'Edit Staff'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personal Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: firstNameController,
                    label: 'First Name *',
                    prefixIcon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: middleNameController,
                    label: 'Middle Name',
                    prefixIcon: Icons.person,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: lastNameController,
                    label: 'Last Name *',
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: identityNumberController,
                    label: 'Identity Number *',
                    prefixIcon: Icons.badge,
                  ),
                  const SizedBox(height: 16),

                  // Birthday picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedBirthday ?? DateTime(1990),
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedBirthday = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Birthday *',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        selectedBirthday != null
                            ? '${selectedBirthday!.day}/${selectedBirthday!.month}/${selectedBirthday!.year}'
                            : 'Select birthday',
                        style: TextStyle(
                          color: selectedBirthday != null
                              ? Colors.black
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: gender,
                    decoration: InputDecoration(
                      labelText: 'Gender *',
                      prefixIcon: const Icon(Icons.wc),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other')),
                    ],
                    onChanged: (value) => setDialogState(() => gender = value!),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: socialStatus,
                    decoration: InputDecoration(
                      labelText: 'Social Status',
                      prefixIcon: const Icon(Icons.family_restroom),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Single', child: Text('Single')),
                      DropdownMenuItem(
                        value: 'Married',
                        child: Text('Married'),
                      ),
                      DropdownMenuItem(
                        value: 'Divorced',
                        child: Text('Divorced'),
                      ),
                      DropdownMenuItem(
                        value: 'Widowed',
                        child: Text('Widowed'),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => socialStatus = value!),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: emailController,
                    label: 'Email *',
                    prefixIcon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: phoneController,
                    label: 'Phone Number *',
                    prefixIcon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Account & Employment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: usernameController,
                    label: 'Username *',
                    prefixIcon: Icons.account_circle,
                  ),
                  const SizedBox(height: 16),

                  if (staff == null) ...[
                    CustomTextField(
                      controller: passwordController,
                      label: 'Password *',
                      prefixIcon: Icons.lock,
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                  ],

                  CustomTextField(
                    controller: employeeNumberController,
                    label: 'Employee Number',
                    prefixIcon: Icons.badge,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: qualificationController,
                    label: 'Qualification',
                    prefixIcon: Icons.school,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: professionLicenseController,
                    label: 'Profession License',
                    prefixIcon: Icons.card_membership,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: salaryController,
                    label: 'Salary',
                    prefixIcon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    controller: bankIbanController,
                    label: 'Bank IBAN',
                    prefixIcon: Icons.account_balance,
                  ),
                  const SizedBox(height: 16),

                  Text(
                    '* Required fields',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate required fields
                if (firstNameController.text.isEmpty ||
                    lastNameController.text.isEmpty ||
                    identityNumberController.text.isEmpty ||
                    emailController.text.isEmpty ||
                    phoneController.text.isEmpty ||
                    usernameController.text.isEmpty ||
                    selectedBirthday == null ||
                    (staff == null && passwordController.text.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields (*)'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                LoadingDialog.show(context);
                try {
                  final data = {
                    'full_name': {
                      'first': firstNameController.text,
                      if (middleNameController.text.isNotEmpty)
                        'middle': middleNameController.text,
                      'last': lastNameController.text,
                    },
                    'identity_number': identityNumberController.text,
                    'birthday': selectedBirthday!.toIso8601String(),
                    'gender': gender,
                    if (socialStatus.isNotEmpty) 'social_status': socialStatus,
                    'email': emailController.text,
                    'phone_number': phoneController.text,
                    'username': usernameController.text,
                    if (staff == null && passwordController.text.isNotEmpty)
                      'password': passwordController.text,
                    if (employeeNumberController.text.isNotEmpty)
                      'employee_number': employeeNumberController.text,
                    if (qualificationController.text.isNotEmpty)
                      'qualification': qualificationController.text,
                    if (professionLicenseController.text.isNotEmpty)
                      'profession_license': professionLicenseController.text,
                    if (salaryController.text.isNotEmpty)
                      'salary': double.tryParse(salaryController.text) ?? 0,
                    if (bankIbanController.text.isNotEmpty)
                      'bank_iban': bankIbanController.text,
                  };

                  final response = staff == null
                      ? await OwnerApiService.createStaff(data)
                      : await OwnerApiService.updateStaff(staff['_id'], data);

                  LoadingDialog.hide(context);
                  if (response['message'] != null) {
                    Navigator.pop(context, true);
                    _loadStaff();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          staff == null
                              ? '✅ Staff created successfully'
                              : '✅ Staff updated successfully',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  LoadingDialog.hide(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: Text(staff == null ? 'Create Staff' : 'Update Staff'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadStaff();
    }
  }

  Future<void> _deleteStaff(String staffId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff'),
        content: const Text(
          'Are you sure you want to delete this staff member?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    LoadingDialog.show(context);
    try {
      final response = await OwnerApiService.deleteStaff(staffId);
      LoadingDialog.hide(context);
      if (response['message'] != null) {
        _loadStaff();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff deleted successfully')),
          );
        }
      }
    } catch (e) {
      LoadingDialog.hide(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showDoctorDialog([Map<String, dynamic>? doctor]) async {
    final firstNameController = TextEditingController(
      text: doctor?['name']?['first'],
    );
    final middleNameController = TextEditingController(
      text: doctor?['name']?['middle'],
    );
    final lastNameController = TextEditingController(
      text: doctor?['name']?['last'],
    );
    final emailController = TextEditingController(text: doctor?['email']);
    final phoneController = TextEditingController(
      text: doctor?['phone_number'],
    );
    final usernameController = TextEditingController(text: doctor?['username']);
    final passwordController = TextEditingController();
    final identityController = TextEditingController(
      text: doctor?['identity_number'],
    );
    DateTime? selectedBirthday = doctor?['birthday'] != null
        ? DateTime.parse(doctor!['birthday'])
        : null;
    String selectedGender = doctor?['gender'] ?? 'Male';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(doctor == null ? 'Add Doctor' : 'Edit Doctor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: firstNameController,
                  label: 'First Name *',
                  prefixIcon: Icons.person,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: middleNameController,
                  label: 'Middle Name',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: lastNameController,
                  label: 'Last Name *',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: identityController,
                  label: 'Identity Number *',
                  prefixIcon: Icons.badge,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedBirthday ?? DateTime(1990),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => selectedBirthday = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Birthday *',
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      selectedBirthday != null
                          ? '${selectedBirthday!.day}/${selectedBirthday!.month}/${selectedBirthday!.year}'
                          : 'Select birthday',
                      style: TextStyle(
                        color: selectedBirthday != null
                            ? Colors.black
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedGender,
                  decoration: InputDecoration(
                    labelText: 'Gender *',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: ['Male', 'Female', 'Other'].map((gender) {
                    return DropdownMenuItem(value: gender, child: Text(gender));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedGender = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: emailController,
                  label: 'Email *',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: phoneController,
                  label: 'Phone *',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: usernameController,
                  label: 'Username *',
                  prefixIcon: Icons.account_circle,
                ),
                if (doctor == null) ...[
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: passwordController,
                    label: 'Password *',
                    prefixIcon: Icons.lock,
                    obscureText: true,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (firstNameController.text.isEmpty ||
                    lastNameController.text.isEmpty ||
                    emailController.text.isEmpty ||
                    usernameController.text.isEmpty ||
                    identityController.text.isEmpty ||
                    phoneController.text.isEmpty ||
                    selectedBirthday == null ||
                    (doctor == null && passwordController.text.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields (*)'),
                    ),
                  );
                  return;
                }

                LoadingDialog.show(context);
                try {
                  final data = doctor == null
                      ? {
                          'full_name': {
                            'first': firstNameController.text,
                            'middle': middleNameController.text,
                            'last': lastNameController.text,
                          },
                          'identity_number': identityController.text,
                          'birthday':
                              '${selectedBirthday!.year}-${selectedBirthday!.month.toString().padLeft(2, '0')}-${selectedBirthday!.day.toString().padLeft(2, '0')}',
                          'gender': selectedGender,
                          'email': emailController.text,
                          'phone': phoneController.text,
                          'username': usernameController.text,
                          'password': passwordController.text,
                        }
                      : {
                          'name': {
                            'first': firstNameController.text,
                            'middle': middleNameController.text,
                            'last': lastNameController.text,
                          },
                          'identity_number': identityController.text,
                          'birthday':
                              '${selectedBirthday!.year}-${selectedBirthday!.month.toString().padLeft(2, '0')}-${selectedBirthday!.day.toString().padLeft(2, '0')}',
                          'gender': selectedGender,
                          'email': emailController.text,
                          'phone_number': phoneController.text,
                          'username': usernameController.text,
                        };

                  final response = doctor == null
                      ? await OwnerApiService.createDoctor(data)
                      : await OwnerApiService.updateDoctor(doctor['_id'], data);

                  if (!context.mounted) return;
                  LoadingDialog.hide(context);

                  if (response['message'] != null &&
                      !response['message'].toString().contains('⚠️') &&
                      !response['message'].toString().contains('❌')) {
                    if (context.mounted) {
                      Navigator.pop(context, true);
                      _loadDoctors();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            doctor == null
                                ? 'Doctor created successfully'
                                : 'Doctor updated successfully',
                          ),
                        ),
                      );
                    }
                  } else {
                    // Show error message from server
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            response['message'] ?? 'Error occurred',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  LoadingDialog.hide(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(doctor == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadDoctors();
    }
  }

  Future<void> _deleteDoctor(String doctorId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Doctor'),
        content: const Text('Are you sure you want to delete this doctor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    LoadingDialog.show(context);
    try {
      final response = await OwnerApiService.deleteDoctor(doctorId);
      if (!context.mounted) return;
      LoadingDialog.hide(context);

      if (response['message'] != null) {
        _loadDoctors();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Doctor deleted successfully')),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      LoadingDialog.hide(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showTestDialog([Map<String, dynamic>? test]) async {
    final nameController = TextEditingController(text: test?['test_name']);
    final testCodeController = TextEditingController(text: test?['test_code']);
    final priceController = TextEditingController(
      text: test?['price']?.toString(),
    );
    final turnaroundController = TextEditingController(
      text: test?['turnaround_time']?.toString(),
    );
    final unitController = TextEditingController(text: test?['units']);
    final methodController = TextEditingController(text: test?['method']);
    final referenceRangeController = TextEditingController(
      text: test?['reference_range'],
    );
    final tubeTypeController = TextEditingController(text: test?['tube_type']);
    final reagentController = TextEditingController(text: test?['reagent']);
    final sampleTypeController = TextEditingController(
      text: test?['sample_type'],
    );
    String? selectedDevice = test?['device_id'];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(test == null ? 'Add Test' : 'Edit Test'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: nameController,
                  label: 'Test Name',
                  prefixIcon: Icons.science,
                ),
                const SizedBox(height: 16),
                if (test == null) ...[
                  CustomTextField(
                    controller: testCodeController,
                    label: 'Test Code',
                    prefixIcon: Icons.code,
                  ),
                  const SizedBox(height: 16),
                ],
                CustomTextField(
                  controller: priceController,
                  label: 'Price',
                  prefixIcon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: turnaroundController,
                  label: 'Turnaround Time (hours)',
                  prefixIcon: Icons.access_time,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: unitController,
                  label: 'Units',
                  prefixIcon: Icons.straighten,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: methodController,
                  label: 'Method',
                  prefixIcon: Icons.biotech,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: referenceRangeController,
                  label: 'Reference Range',
                  prefixIcon: Icons.assessment,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: tubeTypeController,
                  label: 'Tube Type',
                  prefixIcon: Icons.science,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: reagentController,
                  label: 'Reagent',
                  prefixIcon: Icons.liquor,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: sampleTypeController,
                  label: 'Sample Type (e.g., Blood, Urine)',
                  prefixIcon: Icons.bloodtype,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedDevice,
                  decoration: InputDecoration(
                    labelText: 'Device (Optional)',
                    prefixIcon: const Icon(Icons.devices),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No Device'),
                    ),
                    ..._devices.map(
                      (device) => DropdownMenuItem<String>(
                        value: device['_id'],
                        child: Text(
                          device['name'],
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selectedDevice = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty ||
                    (test == null && testCodeController.text.isEmpty) ||
                    priceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Test name, test code (for new tests), and price are required',
                      ),
                    ),
                  );
                  return;
                }

                LoadingDialog.show(context);
                try {
                  final data = {
                    'test_name': nameController.text,
                    if (test == null) 'test_code': testCodeController.text,
                    'price': double.tryParse(priceController.text) ?? 0,
                    'turnaround_time':
                        int.tryParse(turnaroundController.text) ?? 24,
                    'units': unitController.text,
                    'method': methodController.text,
                    'reference_range': referenceRangeController.text,
                    'tube_type': tubeTypeController.text,
                    'reagent': reagentController.text,
                    'sample_type': sampleTypeController.text.isNotEmpty
                        ? sampleTypeController.text
                        : 'Blood',
                    if (selectedDevice != null) 'device_id': selectedDevice,
                  };

                  final response = test == null
                      ? await OwnerApiService.createTest(data)
                      : await OwnerApiService.updateTest(test['_id'], data);

                  if (!context.mounted) return;
                  LoadingDialog.hide(context);
                  if (response['message'] != null) {
                    if (context.mounted) {
                      Navigator.pop(context, true);
                      _loadTests();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            test == null
                                ? 'Test created successfully'
                                : 'Test updated successfully',
                          ),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  LoadingDialog.hide(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(test == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadTests();
    }
  }

  Future<void> _deleteTest(String testId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Test'),
        content: const Text('Are you sure you want to delete this test?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    LoadingDialog.show(context);
    try {
      final response = await OwnerApiService.deleteTest(testId);
      LoadingDialog.hide(context);
      if (response['message'] != null) {
        _loadTests();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Test deleted successfully')),
          );
        }
      }
    } catch (e) {
      LoadingDialog.hide(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showDeviceDialog([Map<String, dynamic>? device]) async {
    final nameController = TextEditingController(text: device?['name']);
    final modelController = TextEditingController(text: device?['model']);
    final serialController = TextEditingController(
      text: device?['serial_number'],
    );
    String? selectedStaff = device?['staff_id'];
    String status = device?['status'] ?? 'active';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(device == null ? 'Add Device' : 'Edit Device'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: nameController,
                  label: 'Device Name',
                  prefixIcon: Icons.devices,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: modelController,
                  label: 'Model',
                  prefixIcon: Icons.device_hub,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: serialController,
                  label: 'Serial Number',
                  prefixIcon: Icons.qr_code,
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: selectedStaff,
                  decoration: InputDecoration(
                    labelText: 'Assigned Staff (Optional)',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Unassigned'),
                    ),
                    ..._staff.map(
                      (s) => DropdownMenuItem<String>(
                        value: s['_id'],
                        child: Text(
                          '${s['full_name']?['first']} ${s['full_name']?['last']}'
                              .trim(),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selectedStaff = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    prefixIcon: const Icon(Icons.info),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                    DropdownMenuItem(
                      value: 'maintenance',
                      child: Text('Maintenance'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => status = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Device name is required')),
                  );
                  return;
                }

                LoadingDialog.show(context);
                try {
                  final data = {
                    'name': nameController.text,
                    'model': modelController.text,
                    'serial_number': serialController.text,
                    'staff_id': selectedStaff,
                    'status': status,
                  };

                  final response = device == null
                      ? await OwnerApiService.createDevice(data)
                      : await OwnerApiService.updateDevice(device['_id'], data);

                  if (!context.mounted) return;
                  LoadingDialog.hide(context);
                  if (response['message'] != null) {
                    if (context.mounted) {
                      Navigator.pop(context, true);
                      _loadDevices();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            device == null
                                ? 'Device created successfully'
                                : 'Device updated successfully',
                          ),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  LoadingDialog.hide(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(device == null ? 'Create' : 'Update'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadDevices();
    }
  }

  Future<void> _deleteDevice(String deviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Device'),
        content: const Text('Are you sure you want to delete this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    LoadingDialog.show(context);
    try {
      final response = await OwnerApiService.deleteDevice(deviceId);
      LoadingDialog.hide(context);
      if (response['message'] != null) {
        _loadDevices();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device deleted successfully')),
          );
        }
      }
    } catch (e) {
      LoadingDialog.hide(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Orders management methods
  Future<void> _loadOrdersInBackground() async {
    if (!mounted) return;

    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);

      final response = await OwnerApiService.getAllOrders(
        status: _selectedStatus?.isNotEmpty == true ? _selectedStatus : null,
      );

      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(response['orders'] ?? []);
          _ordersError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ordersError = 'Failed to load orders: $e';
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    List<Map<String, dynamic>> filtered = _orders;

    // Filter by search query
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((order) {
        final patientName =
            order['patient_name']?.toString().toLowerCase() ?? '';
        final orderId = order['_id']?.toString().toLowerCase() ?? '';
        final doctorName = order['doctor_name']?.toString().toLowerCase() ?? '';
        return patientName.contains(query) ||
            orderId.contains(query) ||
            doctorName.contains(query);
      }).toList();
    }

    // Filter by status
    if (_selectedStatus != null && _selectedStatus!.isNotEmpty) {
      filtered = filtered
          .where(
            (order) =>
                order['status']?.toString().toLowerCase() ==
                _selectedStatus!.toLowerCase(),
          )
          .toList();
    }

    return filtered;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Color _getTestStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.grey;
      case 'assigned':
        return Colors.blue;
      case 'urgent':
        return Colors.red;
      case 'collected':
        return Colors.orange;
      case 'in_progress':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showOrderDetails(BuildContext context, Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue,
                      AppTheme.primaryBlue.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.assignment,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order Details',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '#${order['_id']?.toString().substring(0, min(8, order['_id']?.toString().length ?? 0)) ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
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
                        color: _getStatusColor(order['status'] ?? 'pending'),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getStatusText(order['status'] ?? 'pending'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order Information
                      _buildDialogSection(
                        'Order Information',
                        Icons.info_outline,
                        Colors.blue,
                        [
                          _buildInfoTile(
                            Icons.calendar_today,
                            'Order Date',
                            order['order_date'] != null
                                ? DateTime.parse(
                                    order['order_date'],
                                  ).toString().split(' ')[0]
                                : 'N/A',
                            Colors.blue,
                          ),
                          if (order['barcode'] != null)
                            _buildInfoTile(
                              Icons.qr_code_2,
                              'Barcode',
                              order['barcode'],
                              Colors.purple,
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Patient & Doctor Information
                      _buildDialogSection(
                        'Patient & Doctor',
                        Icons.people,
                        Colors.green,
                        [
                          _buildInfoTile(
                            Icons.person,
                            'Patient',
                            order['patient_name'] ?? 'N/A',
                            Colors.blue,
                          ),
                          _buildInfoTile(
                            Icons.medical_services,
                            'Doctor',
                            order['doctor_name'] ?? 'Not Assigned',
                            Colors.green,
                          ),
                          if (order['requested_by_model'] != null)
                            _buildInfoTile(
                              Icons.person_add,
                              'Requested by',
                              order['requested_by_model'],
                              AppTheme.secondaryTeal,
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Tests & Staff Assignments
                      _buildDialogSection(
                        'Tests & Staff Assignments',
                        Icons.science,
                        Colors.purple,
                        [],
                      ),

                      const SizedBox(height: 8),

                      if (order['order_details'] != null &&
                          order['order_details'] is List)
                        ...List.from(
                          order['order_details'],
                        ).asMap().entries.map<Widget>((entry) {
                          final detail = entry.value;
                          final index = entry.key;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  _getTestStatusColor(
                                    detail['status'] ?? 'pending',
                                  ).withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getTestStatusColor(
                                  detail['status'] ?? 'pending',
                                ).withValues(alpha: 0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: Colors.purple.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.purple,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          detail['test_name'] ?? 'Unknown Test',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppTheme.textDark,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getTestStatusColor(
                                            detail['status'] ?? 'pending',
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          detail['status']
                                                  ?.toString()
                                                  .toUpperCase() ??
                                              'PENDING',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          detail['staff_name'] != null
                                              ? Icons.person
                                              : Icons.person_off,
                                          size: 16,
                                          color: detail['staff_name'] != null
                                              ? Colors.green[700]
                                              : Colors.grey[500],
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Assigned Staff',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              Text(
                                                detail['staff_name'] ??
                                                    'Not yet assigned',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      detail['staff_name'] !=
                                                          null
                                                      ? AppTheme.textDark
                                                      : Colors.grey[500],
                                                  fontStyle:
                                                      detail['staff_name'] !=
                                                          null
                                                      ? FontStyle.normal
                                                      : FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (detail['staff_employee_number'] !=
                                            null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              detail['staff_employee_number'],
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue[700],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),

                                  // Test Result Section
                                  if (detail['has_result'] == true) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.green[50]!,
                                            Colors.green[100]!.withValues(
                                              alpha: 0.3,
                                            ),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.withValues(
                                            alpha: 0.3,
                                          ),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Icon(
                                                  Icons.check_circle,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Test Result Available',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Result Value',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Row(
                                                            children: [
                                                              Text(
                                                                detail['result_value']
                                                                        ?.toString() ??
                                                                    'N/A',
                                                                style: const TextStyle(
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: AppTheme
                                                                      .primaryBlue,
                                                                ),
                                                              ),
                                                              if (detail['result_units'] !=
                                                                  null) ...[
                                                                const SizedBox(
                                                                  width: 4,
                                                                ),
                                                                Text(
                                                                  detail['result_units'],
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    color: Colors
                                                                        .grey[700],
                                                                  ),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (detail['result_reference_range'] !=
                                                        null) ...[
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              'Reference Range',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              detail['result_reference_range'],
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .grey[700],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                if (detail['result_remarks'] !=
                                                    null) ...[
                                                  const SizedBox(height: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange[50],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors.orange
                                                            .withValues(
                                                              alpha: 0.2,
                                                            ),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .note_alt_outlined,
                                                          size: 14,
                                                          color: Colors
                                                              .orange[700],
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                'Remarks',
                                                                style: TextStyle(
                                                                  fontSize: 9,
                                                                  color: Colors
                                                                      .orange[700],
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 2,
                                                              ),
                                                              Text(
                                                                detail['result_remarks'],
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color: Colors
                                                                      .grey[800],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else if (detail['status'] ==
                                      'completed') ...[
                                    // Edge case: Test marked completed but no result (data inconsistency)
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.red[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.red.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            size: 16,
                                            color: Colors.red[700],
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Data inconsistency: Test marked completed but result not uploaded. Please contact staff to upload result.',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.red[700],
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.hourglass_empty,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Test result not available yet',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[600],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        })
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.grey[600]),
                              const SizedBox(width: 8),
                              Text(
                                'No test details available',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.textDark,
              ),
            ),
          ],
        ),
        if (children.isNotEmpty) ...[const SizedBox(height: 8), ...children],
      ],
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogsView() {
    return Container(
      color: Colors.grey[50],
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 80, color: AppTheme.primaryBlue),
              SizedBox(height: 24),
              Text(
                'Audit Logs',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Track all staff activities and system changes',
                style: TextStyle(fontSize: 16, color: AppTheme.textLight),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              Text(
                'Full audit logs feature will be displayed here',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinancialCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 16,
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.red : Colors.black,
              fontSize: isTotal ? 18 : 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, double value) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          '\$${value.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _loadReportsData() async {
    if (!mounted) return;

    setState(() => _isLoadingReports = true);

    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);

      final response = await OwnerApiService.getReports();

      if (mounted) {
        setState(() {
          _reportsData = response;
          _isLoadingReports = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reportsData = null;
          _isLoadingReports = false;
        });
      }
      // Show error message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load reports: $e')));
    }
  }

  Future<void> _showComponentsDialog(Map<String, dynamic> test) async {
    List<Map<String, dynamic>> components = [];
    bool isLoading = true;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isLoading) {
            OwnerApiService.getTestComponents(test['_id'])
                .then((response) {
                  if (response['components'] != null) {
                    setDialogState(() {
                      components = List<Map<String, dynamic>>.from(
                        response['components'],
                      );
                      isLoading = false;
                    });
                  }
                })
                .catchError((e) {
                  setDialogState(() => isLoading = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error loading components: $e')),
                    );
                  }
                });
          }

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.view_list, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Components',
                        style: const TextStyle(fontSize: 18),
                      ),
                      Text(
                        test['test_name'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : components.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.science_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No components yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add components for multi-parameter tests',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: components.length,
                      itemBuilder: (context, index) {
                        final component = components[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green[100],
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              component['component_name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Code: ${component['component_code'] ?? 'N/A'}',
                                ),
                                Text('Units: ${component['units'] ?? 'N/A'}'),
                                Text(
                                  'Range: ${component['reference_range'] ?? 'N/A'}',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    _showComponentFormDialog(
                                      test,
                                      component,
                                    ).then((_) => _showComponentsDialog(test));
                                  },
                                  tooltip: 'Edit Component',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _deleteComponent(
                                        test['_id'],
                                        component['_id'],
                                      ).then((_) {
                                        setDialogState(
                                          () => components.removeAt(index),
                                        );
                                      }),
                                  tooltip: 'Delete Component',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showComponentFormDialog(
                    test,
                  ).then((_) => _showComponentsDialog(test));
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Component'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showComponentFormDialog(
    Map<String, dynamic> test, [
    Map<String, dynamic>? component,
  ]) async {
    final nameController = TextEditingController(
      text: component?['component_name'],
    );
    final codeController = TextEditingController(
      text: component?['component_code'],
    );
    final unitsController = TextEditingController(text: component?['units']);
    final rangeController = TextEditingController(
      text: component?['reference_range'],
    );
    final minController = TextEditingController(
      text: component?['min_value']?.toString(),
    );
    final maxController = TextEditingController(
      text: component?['max_value']?.toString(),
    );
    final orderController = TextEditingController(
      text: component?['display_order']?.toString(),
    );
    final descController = TextEditingController(
      text: component?['description'],
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(component == null ? 'Add Component' : 'Edit Component'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: nameController,
                label: 'Component Name *',
                prefixIcon: Icons.science,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: codeController,
                label: 'Component Code *',
                prefixIcon: Icons.code,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: unitsController,
                label: 'Units (e.g., mg/dL, 10^3/μL)',
                prefixIcon: Icons.straighten,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: rangeController,
                label: 'Reference Range (e.g., 4.5-11.0)',
                prefixIcon: Icons.assessment,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: minController,
                      label: 'Min Value',
                      prefixIcon: Icons.arrow_downward,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: maxController,
                      label: 'Max Value',
                      prefixIcon: Icons.arrow_upward,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: orderController,
                label: 'Display Order',
                prefixIcon: Icons.format_list_numbered,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: descController,
                label: 'Description (Optional)',
                prefixIcon: Icons.description,
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || codeController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Component name and code are required'),
                  ),
                );
                return;
              }

              LoadingDialog.show(context);
              try {
                final data = {
                  'component_name': nameController.text,
                  'component_code': codeController.text,
                  if (unitsController.text.isNotEmpty)
                    'units': unitsController.text,
                  if (rangeController.text.isNotEmpty)
                    'reference_range': rangeController.text,
                  if (minController.text.isNotEmpty)
                    'min_value': double.tryParse(minController.text),
                  if (maxController.text.isNotEmpty)
                    'max_value': double.tryParse(maxController.text),
                  if (orderController.text.isNotEmpty)
                    'display_order': int.tryParse(orderController.text),
                  if (descController.text.isNotEmpty)
                    'description': descController.text,
                };

                final response = component == null
                    ? await OwnerApiService.addTestComponent(test['_id'], data)
                    : await OwnerApiService.updateTestComponent(
                        test['_id'],
                        component['_id'],
                        data,
                      );

                if (!context.mounted) return;
                LoadingDialog.hide(context);

                if (response['message'] != null ||
                    response['component'] != null) {
                  Navigator.pop(context);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        component == null
                            ? 'Component added successfully'
                            : 'Component updated successfully',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (!context.mounted) return;
                LoadingDialog.hide(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text(component == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteComponent(String testId, String componentId) async {
    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Delete Component',
      message: 'Are you sure you want to delete this component?',
      confirmText: 'Delete',
      confirmColor: Colors.red,
      icon: Icons.delete,
    );

    if (!confirm) return;

    LoadingDialog.show(context);
    try {
      final response = await OwnerApiService.deleteTestComponent(
        testId,
        componentId,
      );

      if (!context.mounted) return;
      LoadingDialog.hide(context);

      if (response['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Component deleted successfully')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      LoadingDialog.hide(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class _InventoryManagementWidget extends StatefulWidget {
  const _InventoryManagementWidget();

  @override
  State<_InventoryManagementWidget> createState() =>
      _InventoryManagementWidgetState();
}

class _InventoryManagementWidgetState
    extends State<_InventoryManagementWidget> {
  List<Map<String, dynamic>> _inventoryItems = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);

      final response = await ApiService.get(ApiConfig.ownerInventory);

      setState(() {
        _inventoryItems = List<Map<String, dynamic>>.from(
          response['items'] ?? [],
        );
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load inventory: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _addInventoryItem() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _AddInventoryDialog(),
    );

    if (result != null) {
      await _loadInventory();
    }
  }

  Future<void> _editInventoryItem(Map<String, dynamic> item) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditInventoryDialog(item: item),
    );

    if (result != null) {
      await _loadInventory();
    }
  }

  Future<void> _deleteInventoryItem(String itemId) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Inventory Item',
      message:
          'Are you sure you want to delete this inventory item? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );

    if (confirmed) {
      try {
        final authProvider = Provider.of<OwnerAuthProvider>(
          context,
          listen: false,
        );
        ApiService.setAuthToken(authProvider.token);

        await ApiService.delete('${ApiConfig.ownerInventory}/$itemId');
        await _loadInventory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inventory item deleted successfully'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete item: $e')));
        }
      }
    }
  }

  Future<void> _addStockInput(String itemId) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _StockInputDialog(itemId: itemId),
    );

    if (result != null) {
      await _loadInventory();
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_searchController.text.isEmpty) return _inventoryItems;

    final query = _searchController.text.toLowerCase();
    return _inventoryItems.where((item) {
      final name = item['name']?.toString().toLowerCase() ?? '';
      final itemCode = item['item_code']?.toString().toLowerCase() ?? '';
      return name.contains(query) || itemCode.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    return Container(
      color: Colors.grey[50],
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Column(
          children: [
            // Search and Add Button Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search inventory items...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _addInventoryItem,
                  icon: const Icon(Icons.add),
                  label: Text(isMobile ? 'Add' : 'Add Item'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadInventory,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? 'No inventory items found'
                                : 'No items match your search',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _addInventoryItem,
                            child: const Text('Add First Item'),
                          ),
                        ],
                      ),
                    )
                  : _buildInventoryGrid(isMobile),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryGrid(bool isMobile) {
    int columns = isMobile ? 1 : 2;
    return ListView.builder(
      itemCount: (_filteredItems.length / columns).ceil(),
      itemBuilder: (context, rowIndex) {
        int startIndex = rowIndex * columns;
        List<Widget> rowItems = [];
        for (int i = 0; i < columns; i++) {
          int itemIndex = startIndex + i;
          if (itemIndex < _filteredItems.length) {
            rowItems.add(
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _buildInventoryCard(
                    _filteredItems[itemIndex],
                    isMobile,
                  ),
                ),
              ),
            );
          }
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rowItems,
        );
      },
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item, bool isMobile) {
    final count = item['count'] ?? 0;
    final criticalLevel = item['critical_level'] ?? 0;
    final isLowStock = count <= criticalLevel;
    final expirationDate = item['expiration_date'];
    final isExpiringSoon =
        expirationDate != null &&
        DateTime.parse(expirationDate).difference(DateTime.now()).inDays <= 30;

    return AnimatedCard(
      onTap: () => _editInventoryItem(item),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isLowStock
                ? Colors.red.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.2),
            width: isLowStock ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Unknown Item',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item['item_code'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Code: ${item['item_code']}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editInventoryItem(item);
                        break;
                      case 'add_stock':
                        _addStockInput(item['_id']);
                        break;
                      case 'delete':
                        _deleteInventoryItem(item['_id']);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'edit',
                      height: 32,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 16, color: Colors.blue),
                          const SizedBox(width: 6),
                          const Text('Edit', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'add_stock',
                      height: 32,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle, size: 16, color: Colors.green),
                          const SizedBox(width: 6),
                          const Text(
                            'Add Stock',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      height: 32,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          const SizedBox(width: 6),
                          const Text(
                            'Delete',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock: $count',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: isLowStock ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (criticalLevel > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Critical: $criticalLevel',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.orange),
                        ),
                      ],
                    ],
                  ),
                ),
                if (item['cost'] != null) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${item['cost']}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'per unit',
                        style: TextStyle(fontSize: 8, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            if (isLowStock || isExpiringSoon) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (isLowStock) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'LOW STOCK',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  if (isExpiringSoon) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'EXPIRING SOON',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddInventoryDialog extends StatefulWidget {
  const _AddInventoryDialog();

  @override
  State<_AddInventoryDialog> createState() => _AddInventoryDialogState();
}

class _AddInventoryDialogState extends State<_AddInventoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _itemCodeController = TextEditingController();
  final _costController = TextEditingController();
  final _criticalLevelController = TextEditingController();
  final _countController = TextEditingController();
  DateTime? _expirationDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _itemCodeController.dispose();
    _costController.dispose();
    _criticalLevelController.dispose();
    _countController.dispose();
    super.dispose();
  }

  Future<void> _selectExpirationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _expirationDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);

      final data = {
        'name': _nameController.text.trim(),
        'item_code': _itemCodeController.text.trim(),
        if (_costController.text.isNotEmpty)
          'cost': double.parse(_costController.text),
        if (_criticalLevelController.text.isNotEmpty)
          'critical_level': int.parse(_criticalLevelController.text),
        if (_countController.text.isNotEmpty)
          'count': int.parse(_countController.text),
        if (_expirationDate != null)
          'expiration_date': _expirationDate!.toIso8601String(),
      };

      await ApiService.post(ApiConfig.ownerInventory, data);

      if (mounted) {
        Navigator.of(context).pop(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inventory item added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add item: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Inventory Item'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  hintText: 'Enter item name',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _itemCodeController,
                decoration: const InputDecoration(
                  labelText: 'Item Code',
                  hintText: 'Enter item code (optional)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costController,
                decoration: const InputDecoration(
                  labelText: 'Cost per Unit',
                  hintText: 'Enter cost (optional)',
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _criticalLevelController,
                decoration: const InputDecoration(
                  labelText: 'Critical Level',
                  hintText: 'Minimum stock level (optional)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _countController,
                decoration: const InputDecoration(
                  labelText: 'Initial Count',
                  hintText: 'Current stock count (optional)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectExpirationDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expiration Date',
                    hintText: 'Select expiration date (optional)',
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _expirationDate != null
                            ? '${_expirationDate!.day}/${_expirationDate!.month}/${_expirationDate!.year}'
                            : 'Not set',
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Item'),
        ),
      ],
    );
  }
}

class _EditInventoryDialog extends StatefulWidget {
  final Map<String, dynamic> item;

  const _EditInventoryDialog({required this.item});

  @override
  State<_EditInventoryDialog> createState() => _EditInventoryDialogState();
}

class _EditInventoryDialogState extends State<_EditInventoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _itemCodeController;
  late final TextEditingController _costController;
  late final TextEditingController _criticalLevelController;
  late final TextEditingController _countController;
  DateTime? _expirationDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item['name']);
    _itemCodeController = TextEditingController(text: widget.item['item_code']);
    _costController = TextEditingController(
      text: widget.item['cost']?.toString(),
    );
    _criticalLevelController = TextEditingController(
      text: widget.item['critical_level']?.toString(),
    );
    _countController = TextEditingController(
      text: widget.item['count']?.toString(),
    );

    if (widget.item['expiration_date'] != null) {
      _expirationDate = DateTime.parse(widget.item['expiration_date']);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _itemCodeController.dispose();
    _costController.dispose();
    _criticalLevelController.dispose();
    _countController.dispose();
    super.dispose();
  }

  Future<void> _selectExpirationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _expirationDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _expirationDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);

      final data = {
        'name': _nameController.text.trim(),
        'item_code': _itemCodeController.text.trim(),
        if (_costController.text.isNotEmpty)
          'cost': double.parse(_costController.text),
        if (_criticalLevelController.text.isNotEmpty)
          'critical_level': int.parse(_criticalLevelController.text),
        if (_countController.text.isNotEmpty)
          'count': int.parse(_countController.text),
        if (_expirationDate != null)
          'expiration_date': _expirationDate!.toIso8601String(),
      };

      await ApiService.put(
        '${ApiConfig.ownerInventory}/${widget.item['_id']}',
        data,
      );

      if (mounted) {
        Navigator.of(context).pop(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inventory item updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update item: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Inventory Item'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name *',
                  hintText: 'Enter item name',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _itemCodeController,
                decoration: const InputDecoration(
                  labelText: 'Item Code',
                  hintText: 'Enter item code (optional)',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costController,
                decoration: const InputDecoration(
                  labelText: 'Cost per Unit',
                  hintText: 'Enter cost (optional)',
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _criticalLevelController,
                decoration: const InputDecoration(
                  labelText: 'Critical Level',
                  hintText: 'Minimum stock level (optional)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _countController,
                decoration: const InputDecoration(
                  labelText: 'Current Count',
                  hintText: 'Current stock count (optional)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectExpirationDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expiration Date',
                    hintText: 'Select expiration date (optional)',
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _expirationDate != null
                            ? '${_expirationDate!.day}/${_expirationDate!.month}/${_expirationDate!.year}'
                            : 'Not set',
                      ),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update Item'),
        ),
      ],
    );
  }
}

class _StockInputDialog extends StatefulWidget {
  final String itemId;

  const _StockInputDialog({required this.itemId});

  @override
  State<_StockInputDialog> createState() => _StockInputDialogState();
}

class _StockInputDialogState extends State<_StockInputDialog> {
  final _formKey = GlobalKey<FormState>();
  final _inputValueController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _inputValueController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<OwnerAuthProvider>(
        context,
        listen: false,
      );
      ApiService.setAuthToken(authProvider.token);

      final data = {
        'item_id': widget.itemId,
        'input_value': int.parse(_inputValueController.text),
      };

      await ApiService.post(ApiConfig.ownerInventoryInput, data);

      if (mounted) {
        Navigator.of(context).pop(data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add stock: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Stock Input'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _inputValueController,
          decoration: const InputDecoration(
            labelText: 'Quantity to Add *',
            hintText: 'Enter quantity',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Quantity is required';
            final quantity = int.tryParse(value!);
            if (quantity == null || quantity <= 0) {
              return 'Enter a valid quantity';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Stock'),
        ),
      ],
    );
  }
}

// Expandable Staff Card Widget
class _StaffCardExpanded extends StatefulWidget {
  final Map<String, dynamic> staff;
  final String fullName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StaffCardExpanded({
    required this.staff,
    required this.fullName,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_StaffCardExpanded> createState() => _StaffCardExpandedState();
}

class _StaffCardExpandedState extends State<_StaffCardExpanded> {
  bool isExpanded = false;

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildStaffDetailSection(String title, List<Widget> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 12),
        ...details,
      ],
    );
  }

  Widget _buildStaffDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staff = widget.staff;
    final fullName = widget.fullName;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header with name and actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.withValues(alpha: 0.1),
                  AppTheme.secondaryTeal.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primaryBlue,
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (staff['role'] ?? 'Staff').toString().toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => isExpanded = !isExpanded);
                  },
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.visibility,
                    size: 18,
                  ),
                  label: Text(isExpanded ? 'Hide' : 'See Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expandable details section
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Personal Information Section
                  _buildStaffDetailSection('Personal Information', [
                    _buildStaffDetailRow(
                      Icons.badge,
                      'Identity Number',
                      staff['identity_number'] ?? 'N/A',
                    ),
                    _buildStaffDetailRow(
                      Icons.cake,
                      'Birthday',
                      staff['birthday'] != null
                          ? _formatDate(staff['birthday'])
                          : 'N/A',
                    ),
                    _buildStaffDetailRow(
                      Icons.wc,
                      'Gender',
                      staff['gender'] ?? 'N/A',
                    ),
                    if (staff['social_status'] != null)
                      _buildStaffDetailRow(
                        Icons.family_restroom,
                        'Social Status',
                        staff['social_status'],
                      ),
                  ]),
                  const Divider(height: 32),

                  // Contact Information Section
                  _buildStaffDetailSection('Contact Information', [
                    _buildStaffDetailRow(
                      Icons.email,
                      'Email',
                      staff['email'] ?? 'N/A',
                    ),
                    _buildStaffDetailRow(
                      Icons.phone,
                      'Phone',
                      staff['phone_number'] ?? staff['phone'] ?? 'N/A',
                    ),
                  ]),
                  const Divider(height: 32),

                  // Employment Information Section
                  _buildStaffDetailSection('Employment Information', [
                    _buildStaffDetailRow(
                      Icons.badge,
                      'Employee Number',
                      staff['employee_number'] ?? 'N/A',
                    ),
                    _buildStaffDetailRow(
                      Icons.account_circle,
                      'Username',
                      staff['username'] ?? 'N/A',
                    ),
                    if (staff['qualification'] != null)
                      _buildStaffDetailRow(
                        Icons.school,
                        'Qualification',
                        staff['qualification'],
                      ),
                    if (staff['profession_license'] != null)
                      _buildStaffDetailRow(
                        Icons.card_membership,
                        'License',
                        staff['profession_license'],
                      ),
                    if (staff['salary'] != null)
                      _buildStaffDetailRow(
                        Icons.attach_money,
                        'Salary',
                        '\$${staff['salary']}',
                      ),
                    if (staff['bank_iban'] != null)
                      _buildStaffDetailRow(
                        Icons.account_balance,
                        'Bank IBAN',
                        staff['bank_iban'],
                      ),
                    if (staff['date_hired'] != null)
                      _buildStaffDetailRow(
                        Icons.calendar_today,
                        'Date Hired',
                        _formatDate(staff['date_hired']),
                      ),
                  ]),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

// Expandable Doctor Card Widget
class _DoctorCardExpanded extends StatefulWidget {
  final Map<String, dynamic> doctor;
  final String fullName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DoctorCardExpanded({
    required this.doctor,
    required this.fullName,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_DoctorCardExpanded> createState() => _DoctorCardExpandedState();
}

class _DoctorCardExpandedState extends State<_DoctorCardExpanded> {
  bool isExpanded = false;

  Widget _buildDetailSection(String title, List<Widget> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 12),
        ...details,
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;
    final fullName = widget.fullName;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.withValues(alpha: 0.1),
                  AppTheme.secondaryTeal.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.secondaryTeal,
                  child: const Icon(
                    Icons.medical_services,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryTeal.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (doctor['specialization'] ?? 'DOCTOR')
                              .toString()
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => isExpanded = !isExpanded);
                  },
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.visibility,
                    size: 18,
                  ),
                  label: Text(isExpanded ? 'Hide' : 'See Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection('Contact Information', [
                    _buildDetailRow(
                      Icons.email,
                      'Email',
                      doctor['email'] ?? 'N/A',
                    ),
                    _buildDetailRow(
                      Icons.phone,
                      'Phone',
                      doctor['phone_number'] ?? 'N/A',
                    ),
                  ]),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

// Expandable Test Card Widget
class _TestCardExpanded extends StatefulWidget {
  final Map<String, dynamic> test;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onComponents;

  const _TestCardExpanded({
    required this.test,
    required this.onEdit,
    required this.onDelete,
    required this.onComponents,
  });

  @override
  State<_TestCardExpanded> createState() => _TestCardExpandedState();
}

class _TestCardExpandedState extends State<_TestCardExpanded> {
  bool isExpanded = false;

  Widget _buildDetailSection(String title, List<Widget> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 12),
        ...details,
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final test = widget.test;
    final testName = test['test_name'] ?? 'Unknown Test';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.withValues(alpha: 0.1),
                  Colors.deepPurple.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.purple,
                  child: const Icon(
                    Icons.science,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '\$${test['price'] ?? 0}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => isExpanded = !isExpanded);
                  },
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.visibility,
                    size: 18,
                  ),
                  label: Text(isExpanded ? 'Hide' : 'See Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection('Test Information', [
                    _buildDetailRow(
                      Icons.qr_code,
                      'Test Code',
                      test['test_code'] ?? 'N/A',
                    ),
                    _buildDetailRow(
                      Icons.attach_money,
                      'Price',
                      '\$${test['price'] ?? 0}',
                    ),
                    if (test['category'] != null)
                      _buildDetailRow(
                        Icons.category,
                        'Category',
                        test['category'],
                      ),
                    if (test['description'] != null)
                      _buildDetailRow(
                        Icons.description,
                        'Description',
                        test['description'],
                      ),
                    if (test['duration'] != null)
                      _buildDetailRow(
                        Icons.timer,
                        'Duration',
                        '${test['duration']} minutes',
                      ),
                    if (test['sample_type'] != null)
                      _buildDetailRow(
                        Icons.biotech,
                        'Sample Type',
                        test['sample_type'],
                      ),
                  ]),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.onComponents,
                        icon: const Icon(Icons.list_alt, size: 18),
                        label: const Text('Components'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

// Expandable Device Card Widget
class _DeviceCardExpanded extends StatefulWidget {
  final Map<String, dynamic> device;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DeviceCardExpanded({
    required this.device,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_DeviceCardExpanded> createState() => _DeviceCardExpandedState();
}

class _DeviceCardExpandedState extends State<_DeviceCardExpanded> {
  bool isExpanded = false;

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildDetailSection(String title, List<Widget> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 12),
        ...details,
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final deviceName = device['name'] ?? 'Unknown Device';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withValues(alpha: 0.1),
                  Colors.deepOrange.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.orange,
                  child: const Icon(
                    Icons.devices,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            device['status'],
                          ).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (device['status'] ?? 'UNKNOWN')
                              .toString()
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(device['status']),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => isExpanded = !isExpanded);
                  },
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.visibility,
                    size: 18,
                  ),
                  label: Text(isExpanded ? 'Hide' : 'See Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection('Device Information', [
                    _buildDetailRow(
                      Icons.confirmation_number,
                      'Serial Number',
                      device['serial_number'] ?? 'N/A',
                    ),
                    _buildDetailRow(
                      Icons.category,
                      'Model',
                      device['model'] ?? 'N/A',
                    ),
                    _buildDetailRow(
                      Icons.business,
                      'Manufacturer',
                      device['manufacturer'] ?? 'N/A',
                    ),
                    if (device['purchase_date'] != null)
                      _buildDetailRow(
                        Icons.shopping_cart,
                        'Purchase Date',
                        _formatDate(device['purchase_date']),
                      ),
                    if (device['warranty_expiry'] != null)
                      _buildDetailRow(
                        Icons.shield,
                        'Warranty Expiry',
                        _formatDate(device['warranty_expiry']),
                      ),
                    if (device['last_maintenance'] != null)
                      _buildDetailRow(
                        Icons.build,
                        'Last Maintenance',
                        _formatDate(device['last_maintenance']),
                      ),
                    if (device['next_maintenance'] != null)
                      _buildDetailRow(
                        Icons.event,
                        'Next Maintenance',
                        _formatDate(device['next_maintenance']),
                      ),
                  ]),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'operational':
      case 'active':
        return Colors.green;
      case 'maintenance':
        return Colors.orange;
      case 'faulty':
      case 'inactive':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
