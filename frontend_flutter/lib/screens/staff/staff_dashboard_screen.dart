// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/staff_auth_provider.dart';
import '../../services/staff_api_service.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';
import '../../widgets/barcode_display_widget.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/paginated_list.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'staff_sidebar.dart';
import '../../widgets/system_feedback_form.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _assignedTests;
  Map<String, dynamic>? _pendingOrders;
  List<Map<String, dynamic>>? _dropdownInventoryItems;
  bool _isTestsLoading = false;
  bool _isOrdersLoading = false;
  String? _selectedStatus;
  String? _selectedDeviceId;
  late TabController _tabController;

  // Sidebar state
  int _selectedIndex = 0;
  bool _isSidebarOpen = true;
  bool _hasFeedbackSubmitted = false;
  bool _showFeedbackReminder = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadInitialData();
    _checkFeedbackStatus();
  }

  Future<void> _checkFeedbackStatus() async {
    try {
      final response = await StaffApiService.getMyFeedback();
      if (mounted) {
        setState(() {
          _hasFeedbackSubmitted =
              (response['feedbacks'] as List?)?.isNotEmpty ?? false;
          _showFeedbackReminder = !_hasFeedbackSubmitted;
        });
      }
    } catch (e) {
      // If error, assume no feedback submitted
      if (mounted) {
        setState(() {
          _hasFeedbackSubmitted = false;
          _showFeedbackReminder = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Load only the first tab's data initially
  Future<void> _loadInitialData() async {
    await _loadAssignedTests();
  }

  // Handle tab changes to load data on demand
  void _handleTabChange() {
    if (_tabController.index == 1 &&
        _pendingOrders == null &&
        !_isOrdersLoading) {
      _loadPendingOrders();
    }
    // Inventory tab now uses PaginatedList, no need for manual loading
  }

  Future<void> _loadAssignedTests() async {
    if (_isTestsLoading) return; // Prevent multiple simultaneous loads
    setState(() => _isTestsLoading = true);

    try {
      final response = await StaffApiService.getMyAssignedTests(
        statusFilter: _selectedStatus,
        deviceId: _selectedDeviceId,
      );

      if (mounted) {
        setState(() {
          _assignedTests = response;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load assigned tests: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTestsLoading = false);
      }
    }
  }

  Future<void> _loadPendingOrders() async {
    if (_isOrdersLoading) return;
    setState(() => _isOrdersLoading = true);

    try {
      final response = await StaffApiService.getPendingOrders();
      if (mounted) {
        setState(() {
          _pendingOrders = response;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load pending orders: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOrdersLoading = false);
      }
    }
  }

  Future<void> _loadDropdownInventoryItems() async {
    try {
      final response = await StaffApiService.getInventoryItems(
        page: 1,
        limit: 1000,
      ); // Load more for dropdown
      if (mounted) {
        setState(() {
          _dropdownInventoryItems = List<Map<String, dynamic>>.from(
            response['data'] ?? [],
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load inventory for dropdown: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _fetchInventoryPage(int page, int limit) async {
    try {
      final response = await StaffApiService.getInventoryItems(
        page: page,
        limit: limit,
      );
      return {
        'data': response['data'] ?? [],
        'hasMore': response['pagination']?['hasMore'] ?? false,
      };
    } catch (e) {
      throw Exception('Failed to load inventory: $e');
    }
  }

  Future<void> _showReportInventoryIssueDialog() async {
    // Load inventory items for dropdown if not already loaded
    if (_dropdownInventoryItems == null) {
      await _loadDropdownInventoryItems();
    }

    final inventoryController = TextEditingController();
    final quantityController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedIssueType = 'damaged';

    final inventoryItems = _dropdownInventoryItems ?? [];

    await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.report_problem, color: AppTheme.warningYellow),
              const SizedBox(width: 8),
              const Text('Report Inventory Issue'),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedIssueType,
                    decoration: const InputDecoration(
                      labelText: 'Issue Type',
                      hintText: 'Select the type of issue',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'damaged',
                        child: Text('Damaged'),
                      ),
                      DropdownMenuItem(
                        value: 'expired',
                        child: Text('Expired'),
                      ),
                      DropdownMenuItem(
                        value: 'contaminated',
                        child: Text('Contaminated'),
                      ),
                      DropdownMenuItem(
                        value: 'missing',
                        child: Text('Missing'),
                      ),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      setState(() => selectedIssueType = value ?? 'damaged');
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Inventory Item',
                      hintText: 'Select the affected item',
                    ),
                    items: inventoryItems.map((item) {
                      final name = item['name'] as String? ?? 'Unknown';
                      final currentStock = item['current_stock'] as int? ?? 0;
                      return DropdownMenuItem(
                        value: item['_id']?.toString(),
                        child: Text('$name (Stock: $currentStock)'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      inventoryController.text = value ?? '';
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity Affected',
                      hintText: 'Enter the quantity affected',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'Provide additional details',
                    ),
                    maxLines: 3,
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
                if (inventoryController.text.isNotEmpty &&
                    quantityController.text.isNotEmpty) {
                  Navigator.pop(context, true);

                  final quantity = int.tryParse(quantityController.text) ?? 0;
                  if (quantity <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid quantity'),
                        backgroundColor: AppTheme.errorRed,
                      ),
                    );
                    return;
                  }

                  try {
                    final response = await StaffApiService.reportInventoryIssue(
                      inventoryId: inventoryController.text,
                      issueType: selectedIssueType,
                      quantity: quantity,
                      description: descriptionController.text.isEmpty
                          ? null
                          : descriptionController.text,
                    );

                    if (context.mounted) {
                      if (response['success'] != false) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Inventory issue reported successfully',
                            ),
                            backgroundColor: AppTheme.successGreen,
                          ),
                        );
                        // Refresh dropdown inventory items
                        _loadDropdownInventoryItems();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              response['message'] ?? 'Failed to report issue',
                            ),
                            backgroundColor: AppTheme.errorRed,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to report issue: $e'),
                          backgroundColor: AppTheme.errorRed,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningYellow,
                foregroundColor: Colors.black,
              ),
              child: const Text('Report Issue'),
            ),
          ],
        ),
      ),
    );

    inventoryController.dispose();
    quantityController.dispose();
    descriptionController.dispose();
  }

  Future<void> _showConsumeInventoryDialog(Map<String, dynamic> item) async {
    final quantityController = TextEditingController();
    final reasonController = TextEditingController();
    final currentStock = item['current_stock'] as int? ?? 0;
    final itemName = item['name'] as String? ?? 'Unknown Item';

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.remove_circle, color: AppTheme.warningYellow),
            const SizedBox(width: 8),
            Text('Consume $itemName'),
          ],
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Current stock: $currentStock'),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity to Consume',
                    hintText: 'Enter the quantity to consume',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason (Optional)',
                    hintText: 'e.g., Used for sample collection',
                  ),
                  maxLines: 2,
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
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid quantity'),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
                return;
              }

              if (quantity > currentStock) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Cannot consume more than available stock ($currentStock)',
                    ),
                    backgroundColor: AppTheme.errorRed,
                  ),
                );
                return;
              }

              Navigator.pop(context, true);

              try {
                final response = await StaffApiService.consumeInventory(
                  inventoryId: item['_id']?.toString() ?? '',
                  quantity: quantity,
                  reason: reasonController.text.isEmpty
                      ? null
                      : reasonController.text,
                );

                if (context.mounted) {
                  if (response['success'] != false) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Inventory consumed successfully'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                    // Refresh inventory list
                    setState(() {
                      // Trigger refresh by calling _loadInitialData or similar
                      // For now, just show success
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          response['message'] ?? 'Failed to consume inventory',
                        ),
                        backgroundColor: AppTheme.errorRed,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to consume inventory: $e'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningYellow,
              foregroundColor: Colors.black,
            ),
            child: const Text('Consume'),
          ),
        ],
      ),
    );

    quantityController.dispose();
    reasonController.dispose();
  }

  Widget _buildInventoryItemCard(Map<String, dynamic> item) {
    final name = item['name'] as String? ?? 'Unknown Item';
    final currentStock = item['current_stock'] as int? ?? 0;
    final unit = item['unit'] as String? ?? 'units';
    final minThreshold = item['min_threshold'] as int? ?? 0;
    final isLowStock = currentStock <= minThreshold;

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isLowStock
              ? AppTheme.errorRed.withValues(alpha: 0.2)
              : AppTheme.primaryBlue.withValues(alpha: 0.2),
          child: Icon(
            isLowStock ? Icons.warning : Icons.inventory,
            color: isLowStock ? AppTheme.errorRed : AppTheme.primaryBlue,
          ),
        ),
        title: Text(name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stock: $currentStock $unit'),
            if (isLowStock)
              Text(
                'Low stock alert!',
                style: TextStyle(
                  color: AppTheme.errorRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.remove_circle,
                color: AppTheme.warningYellow,
              ),
              onPressed: () => _showConsumeInventoryDialog(item),
              tooltip: 'Consume Item',
            ),
            if (isLowStock)
              Icon(Icons.warning, color: AppTheme.errorRed)
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Future<void> _collectSample(String detailId) async {
    if (detailId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid test ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final response = await StaffApiService.collectSample(detailId: detailId);

    if (mounted) {
      if (response['success'] != false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample collected successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        _loadAssignedTests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to collect sample'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _showUploadResultDialog(Map<String, dynamic> test) async {
    final resultController = TextEditingController();
    final remarksController = TextEditingController();

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Upload Result - ${test['test_name'] as String? ?? 'Unknown Test'}',
        ),
        content: SingleChildScrollView(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: resultController,
                  decoration: const InputDecoration(
                    labelText: 'Result Value',
                    hintText: 'Enter test result',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: remarksController,
                  decoration: const InputDecoration(
                    labelText: 'Remarks (Optional)',
                    hintText: 'Any additional notes',
                  ),
                  maxLines: 3,
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
              if (resultController.text.isNotEmpty) {
                Navigator.pop(context, true);

                final response = await StaffApiService.uploadResult(
                  detailId: test['_id']?.toString() ?? '',
                  resultValue: resultController.text,
                  remarks: remarksController.text.isEmpty
                      ? null
                      : remarksController.text,
                );

                if (context.mounted) {
                  if (response['success'] != false) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Result uploaded successfully'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                    _loadAssignedTests();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          response['message'] ?? 'Failed to upload result',
                        ),
                        backgroundColor: AppTheme.errorRed,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    resultController.dispose();
    remarksController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<StaffAuthProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 1024;
    final screenWidth = MediaQuery.of(context).size.width;

    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/staff/login');
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
                  Text(
                    'Staff Dashboard',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Welcome back, ${authProvider.user?.fullName?.first ?? authProvider.user?.email ?? 'Staff'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: _showNotificationsDialog,
                ),
              ],
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
                onPressed: () =>
                    setState(() => _isSidebarOpen = !_isSidebarOpen),
                tooltip: _isSidebarOpen ? 'Close sidebar' : 'Open sidebar',
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Staff Dashboard',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Welcome back, ${authProvider.user?.fullName?.first ?? authProvider.user?.email ?? 'Staff'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: _showNotificationsDialog,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
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
                        Icons.biotech,
                        color: AppTheme.primaryBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Lab Staff',
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
              builder: (context) =>
                  AppAnimations.slideInFromLeft(_buildDrawer()),
            )
          : null,
      body: Stack(
        children: [
          Row(
            children: [
              if (!isMobile && _isSidebarOpen)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 280,
                  child: StaffSidebar(
                    selectedIndex: _selectedIndex,
                    onItemSelected: (index) =>
                        setState(() => _selectedIndex = index),
                  ),
                ),
              Expanded(
                child: AppAnimations.fadeIn(
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
    );
  }

  void _showFeedbackDialog() {
    showDialog(
      context: context,
      builder: (context) => SystemFeedbackForm(
        onSubmit: (feedbackData) async {
          try {
            await StaffApiService.provideFeedback(
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
                  const Icon(Icons.biotech, size: 48, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    'Lab Staff',
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
                children: [
                  _buildDrawerItem('Dashboard', Icons.dashboard, 0),
                  _buildDrawerItem('My Tests', Icons.assignment, 1),
                  _buildDrawerItem('Sample Collection', Icons.science, 2),
                  _buildDrawerItem('Result Upload', Icons.upload_file, 3),
                  _buildDrawerItem('Barcode Generation', Icons.qr_code, 4),
                  _buildDrawerItem('Inventory', Icons.inventory, 5),
                  _buildDrawerItem('Notifications', Icons.notifications, 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(String title, IconData icon, int index) {
    final isSelected = _selectedIndex == index;
    return AnimatedCard(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Icon(
            icon,
            color: isSelected ? AppTheme.primaryBlue : AppTheme.textLight,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryBlue : AppTheme.textDark,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          selected: isSelected,
          selectedTileColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
          onTap: () {
            setState(() => _selectedIndex = index);
            Navigator.pop(context); // Close drawer
          },
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardView();
      case 1:
        return _buildMyTestsView();
      case 2:
        return _buildSampleCollectionView();
      case 3:
        return _buildResultUploadView();
      case 4:
        return _buildBarcodeGenerationView();
      case 5:
        return _buildInventoryView();
      case 6:
        return _buildNotificationsView();
      default:
        return _buildDashboardView();
    }
  }

  Widget _buildDashboardView() {
    return RefreshIndicator(
      onRefresh: _loadAssignedTests,
      child: AppAnimations.pageDepthTransition(
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_showFeedbackReminder)
                AppAnimations.elasticSlideIn(
                  _buildFeedbackReminderBanner(),
                  delay: 50.ms,
                ),
              if (_showFeedbackReminder) const SizedBox(height: 16),
              AppAnimations.blurFadeIn(_buildHeroSection(), delay: 100.ms),
              const SizedBox(height: 24),
              AppAnimations.elasticSlideIn(_buildStatsSection(), delay: 300.ms),
              const SizedBox(height: 24),
              // AppAnimations.elasticSlideIn(_buildFilters(), delay: 500.ms),
              // const SizedBox(height: 16),
              AppAnimations.fadeIn(_buildTestsList(), delay: 700.ms),
            ],
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

  Widget _buildMyTestsView() {
    return _buildDashboardView(); // For now, same as dashboard
  }

  Widget _buildSampleCollectionView() {
    return AppAnimations.pageDepthTransition(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAnimations.blurFadeIn(
              Text(
                'Sample Collection',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              delay: 100.ms,
            ),
            const SizedBox(height: 16),
            AppAnimations.fadeIn(
              Text(
                'Collect samples for assigned tests',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              delay: 200.ms,
            ),
            const SizedBox(height: 24),
            // Show tests that need sample collection
            AppAnimations.fadeIn(_buildSampleCollectionList(), delay: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildResultUploadView() {
    return AppAnimations.pageDepthTransition(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAnimations.blurFadeIn(
              Text(
                'Result Upload',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              delay: 100.ms,
            ),
            const SizedBox(height: 16),
            AppAnimations.fadeIn(
              Text(
                'Upload test results for completed tests',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              delay: 200.ms,
            ),
            const SizedBox(height: 24),
            // Show tests that need result upload
            AppAnimations.fadeIn(_buildResultUploadList(), delay: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildBarcodeGenerationView() {
    // Get orders that don't have barcodes
    final testsByStatus = _assignedTests?['tests_by_status'] as Map? ?? {};
    final allTests = [
      ...(testsByStatus['assigned'] as List? ?? []),
      ...(testsByStatus['collected'] as List? ?? []),
      ...(testsByStatus['in_progress'] as List? ?? []),
      ...(testsByStatus['urgent'] as List? ?? []),
    ];

    // Get unique orders that don't have barcodes
    final ordersWithoutBarcodes = allTests
        .where((test) => (test['order_barcode'] as String?)?.isEmpty ?? true)
        .fold<Map<String, Map<String, dynamic>>>({}, (map, test) {
          final orderId =
              test['order_id']?.toString() ??
              test['order_id']?['_id']?.toString();
          if (orderId != null && !map.containsKey(orderId)) {
            map[orderId] = test;
          }
          return map;
        })
        .values
        .toList();

    return RefreshIndicator(
      onRefresh: _loadAssignedTests,
      child: AppAnimations.pageDepthTransition(
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAnimations.blurFadeIn(
                Text(
                  'Order Barcode Generation',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                delay: 100.ms,
              ),
              const SizedBox(height: 16),
              AppAnimations.fadeIn(
                Text(
                  'Generate unique barcodes for orders. Each barcode will be assigned to all test samples in that order.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                delay: 200.ms,
              ),
              const SizedBox(height: 24),
              if (_isTestsLoading)
                const Center(child: CircularProgressIndicator())
              else if (ordersWithoutBarcodes.isEmpty)
                AppAnimations.fadeIn(
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No orders requiring barcode generation'),
                    ),
                  ),
                  delay: 300.ms,
                )
              else
                ...ordersWithoutBarcodes.map(
                  (test) => AppAnimations.elasticSlideIn(
                    _buildOrderBarcodeCard(test),
                    delay:
                        300.ms + (ordersWithoutBarcodes.indexOf(test) * 100).ms,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryView() {
    return AppAnimations.pageDepthTransition(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAnimations.blurFadeIn(
              Text(
                'Inventory Management',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              delay: 100.ms,
            ),
            const SizedBox(height: 16),
            AppAnimations.fadeIn(
              Text(
                'Report inventory issues or check current stock levels',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              delay: 200.ms,
            ),
            const SizedBox(height: 24),
            AppAnimations.elasticSlideIn(
              AnimatedCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning,
                            color: AppTheme.warningYellow,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Report Inventory Issue',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'If you notice damaged, expired, contaminated, or missing inventory items, please report them immediately.',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.report_problem),
                          label: const Text('Report Issue'),
                          onPressed: _showReportInventoryIssueDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.warningYellow,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              delay: 300.ms,
            ),
            const SizedBox(height: 24),
            AppAnimations.elasticSlideIn(
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: PaginatedList<Map<String, dynamic>>(
                  fetchData: _fetchInventoryPage,
                  itemBuilder: _buildInventoryItemCard,
                  emptyMessage: 'No inventory items found',
                  loadingMessage: 'Loading inventory...',
                  initialLimit: 20,
                  header: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inventory,
                          color: AppTheme.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Current Inventory',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              delay: 400.ms,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsView() {
    return AppAnimations.pageDepthTransition(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppAnimations.floating(
                AppAnimations.morphIn(
                  Icon(
                    Icons.notifications,
                    size: 80,
                    color: AppTheme.primaryBlue,
                  ),
                  delay: 200.ms,
                ),
              ),
              const SizedBox(height: 16),
              AppAnimations.blurFadeIn(
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                delay: 400.ms,
              ),
              const SizedBox(height: 8),
              AppAnimations.elasticSlideIn(
                Text(
                  'View your notifications and updates',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                delay: 600.ms,
              ),
              const SizedBox(height: 24),
              AppAnimations.tilt3D(
                AnimatedButton(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.notifications),
                    label: const Text('View Notifications'),
                    onPressed: _showNotificationsDialog,
                  ),
                ),
                delay: 800.ms,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSampleCollectionList() {
    final testsByStatus = _assignedTests?['tests_by_status'] as Map? ?? {};
    final assignedTests = testsByStatus['assigned'] as List? ?? [];

    if (assignedTests.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No tests assigned for sample collection'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: assignedTests
          .map((test) => _buildSampleCollectionCard(test))
          .toList(),
    );
  }

  Widget _buildResultUploadList() {
    final testsByStatus = _assignedTests?['tests_by_status'] as Map? ?? {};
    final collectedTests = testsByStatus['collected'] as List? ?? [];
    final inProgressTests = testsByStatus['in_progress'] as List? ?? [];
    final allTests = [...collectedTests, ...inProgressTests];

    if (allTests.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No tests ready for result upload'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: allTests.map((test) => _buildResultUploadCard(test)).toList(),
    );
  }

  Widget _buildSampleCollectionCard(Map<String, dynamic> test) {
    final testName = test['test_name'] as String? ?? 'Unknown Test';
    final patientName = test['patient_name'] as String? ?? 'N/A';
    final sampleBarcode = test['sample_barcode'] as String? ?? 'Not generated';
    final testId = test['_id']?.toString();

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science, color: AppTheme.secondaryTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    testName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Patient: $patientName'),
            Text('Sample Barcode: $sampleBarcode'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('Mark as Collected'),
                onPressed: testId != null && testId.isNotEmpty
                    ? () => _collectSample(testId)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryTeal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultUploadCard(Map<String, dynamic> test) {
    final testName = test['test_name'] as String? ?? 'Unknown Test';
    final patientName = test['patient_name'] as String? ?? 'N/A';
    final status = test['status'] as String? ?? 'pending';
    final testId = test['_id']?.toString();

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.upload_file, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    testName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status == 'collected'
                        ? AppTheme.secondaryTeal.withValues(alpha: 0.2)
                        : AppTheme.warningYellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status == 'collected' ? 'Collected' : 'In Progress',
                    style: TextStyle(
                      color: status == 'collected'
                          ? AppTheme.secondaryTeal
                          : AppTheme.warningYellow,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Patient: $patientName'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.upload),
                label: const Text('Upload Result'),
                onPressed: testId != null && testId.isNotEmpty
                    ? () => _showUploadResultDialog(test)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderBarcodeCard(Map<String, dynamic> test) {
    final authProvider = Provider.of<StaffAuthProvider>(context);

    final orderId =
        test['order_id']?.toString() ?? test['order_id']?['_id']?.toString();
    if (orderId == null) return const SizedBox.shrink();

    final patientName =
        test['patient']?['name'] as String? ?? 'Unknown Patient';

    // Count tests in this order
    final testsByStatus = _assignedTests?['tests_by_status'] as Map? ?? {};
    final allTests = [
      ...(testsByStatus['assigned'] as List? ?? []),
      ...(testsByStatus['collected'] as List? ?? []),
      ...(testsByStatus['in_progress'] as List? ?? []),
      ...(testsByStatus['urgent'] as List? ?? []),
    ];

    final testCount = allTests
        .where(
          (t) =>
              t['order_id']?.toString() == orderId ||
              t['order_id']?['_id']?.toString() == orderId,
        )
        .length;

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.qr_code, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Order Barcode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Patient: $patientName',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Tests in Order: $testCount',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Order ID: $orderId',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            BarcodeDisplayWidget(
              orderId: orderId,
              token: authProvider.token ?? '',
              onBarcodeGenerated: () {
                _loadAssignedTests(); // Refresh the list
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final stats = _assignedTests?['stats'] ?? {};

    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Workload', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                AppAnimations.scaleIn(
                  _buildStatItem(
                    'Total',
                    stats['total']?.toString() ?? '0',
                    AppTheme.primaryBlue,
                  ),
                  delay: 100.ms,
                ),
                AppAnimations.scaleIn(
                  _buildStatItem(
                    'Urgent',
                    stats['urgent']?.toString() ?? '0',
                    AppTheme.errorRed,
                  ),
                  delay: 200.ms,
                ),
                AppAnimations.scaleIn(
                  _buildStatItem(
                    'Pending',
                    stats['pending_work']?.toString() ?? '0',
                    AppTheme.warningYellow,
                  ),
                  delay: 300.ms,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final stats = _assignedTests?['stats'] ?? {};

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAnimations.liquidMorph(
            Row(
              children: [
                AppAnimations.rotateIn(
                  Icon(
                    Icons.biotech,
                    size: 56,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  delay: 200.ms,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppAnimations.typingEffect(
                        'Welcome to Your Lab Workstation',
                        Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ) ??
                            const TextStyle(),
                      ),
                      const SizedBox(height: 8),
                      AppAnimations.fadeIn(
                        Text(
                          'Manage your assigned tests and laboratory operations',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 18,
                                height: 1.4,
                              ),
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
              spacing: 20,
              runSpacing: 16,
              children: [
                AppAnimations.glowPulse(
                  _buildEnhancedHeroMetric(
                    'Total Tests',
                    stats['total']?.toString() ?? '0',
                    Icons.assignment,
                    AppTheme.primaryBlue,
                  ),
                  glowColor: AppTheme.primaryBlue,
                ),
                AppAnimations.glowPulse(
                  _buildEnhancedHeroMetric(
                    'Urgent Tests',
                    stats['urgent']?.toString() ?? '0',
                    Icons.priority_high,
                    AppTheme.errorRed,
                  ),
                  glowColor: AppTheme.errorRed,
                ),
                AppAnimations.glowPulse(
                  _buildEnhancedHeroMetric(
                    'Pending Work',
                    stats['pending_work']?.toString() ?? '0',
                    Icons.pending,
                    AppTheme.warningYellow,
                  ),
                  glowColor: AppTheme.warningYellow,
                ),
              ],
            ),
            delay: 600.ms,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        SelectableText(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  /*
  Widget _buildFilters() {
    return AnimatedCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppAnimations.scaleIn(
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedStatus == null,
                    onSelected: (selected) {
                      setState(() => _selectedStatus = null);
                      _loadAssignedTests();
                    },
                  ),
                  delay: 100.ms,
                ),
                AppAnimations.scaleIn(
                  ChoiceChip(
                    label: const Text('Urgent'),
                    selected: _selectedStatus == 'urgent',
                    selectedColor: AppTheme.errorRed.withValues(alpha: 0.3),
                    onSelected: (selected) {
                      setState(
                        () => _selectedStatus = selected ? 'urgent' : null,
                      );
                      _loadAssignedTests();
                    },
                  ),
                  delay: 200.ms,
                ),
                AppAnimations.scaleIn(
                  ChoiceChip(
                    label: const Text('Assigned'),
                    selected: _selectedStatus == 'assigned',
                    onSelected: (selected) {
                      setState(
                        () => _selectedStatus = selected ? 'assigned' : null,
                      );
                      _loadAssignedTests();
                    },
                  ),
                  delay: 300.ms,
                ),
                AppAnimations.scaleIn(
                  ChoiceChip(
                    label: const Text('In Progress'),
                    selected: _selectedStatus == 'in_progress',
                    onSelected: (selected) {
                      setState(
                        () => _selectedStatus = selected ? 'in_progress' : null,
                      );
                      _loadAssignedTests();
                    },
                  ),
                  delay: 400.ms,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  */

  Widget _buildTestsList() {
    final testsByStatus = _assignedTests?['tests_by_status'] as Map? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (testsByStatus['urgent']?.isNotEmpty ?? false) ...[
          _buildTestsGroup(
            'Urgent Tests',
            testsByStatus['urgent'],
            AppTheme.errorRed,
          ),
          const SizedBox(height: 16),
        ],
        if (testsByStatus['assigned']?.isNotEmpty ?? false) ...[
          _buildTestsGroup(
            'Assigned Tests',
            testsByStatus['assigned'],
            AppTheme.primaryBlue,
          ),
          const SizedBox(height: 16),
        ],
        if (testsByStatus['collected']?.isNotEmpty ?? false) ...[
          _buildTestsGroup(
            'Collected Samples',
            testsByStatus['collected'],
            AppTheme.secondaryTeal,
          ),
          const SizedBox(height: 16),
        ],
        if (testsByStatus['in_progress']?.isNotEmpty ?? false) ...[
          _buildTestsGroup(
            'In Progress',
            testsByStatus['in_progress'],
            AppTheme.warningYellow,
          ),
          const SizedBox(height: 16),
        ],
        if (testsByStatus['completed']?.isNotEmpty ?? false) ...[
          _buildTestsGroup(
            'Completed',
            testsByStatus['completed'],
            AppTheme.successGreen,
          ),
        ],
      ],
    );
  }

  Widget _buildTestsGroup(String title, List tests, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(tests.length.toString()),
              backgroundColor: color.withValues(alpha: 0.2),
              labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...tests.map((test) => _buildTestCard(test)),
      ],
    );
  }

  Widget _buildTestCard(Map<String, dynamic> test) {
    final status = test['status'] as String? ?? 'pending';
    final sampleCollected = test['sample_collected'] as bool? ?? false;
    final testName = test['test_name'] as String? ?? 'Unknown Test';
    final patientName = test['patient_name'] as String? ?? 'N/A';
    final sampleBarcode = test['sample_barcode'] as String? ?? 'Not generated';
    final deviceName = test['device']?['name'] as String?;

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(status).withValues(alpha: 0.2),
          child: Icon(_getStatusIcon(status), color: _getStatusColor(status)),
        ),
        title: SelectableText(testName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('Patient: $patientName'),
            SelectableText('Sample Barcode: $sampleBarcode'),
            if (deviceName != null) SelectableText('Device: $deviceName'),
          ],
        ),
        trailing: _buildActionButton(test, status, sampleCollected),
        isThreeLine: true,
      ),
    );
  }

  Widget? _buildActionButton(
    Map<String, dynamic> test,
    String status,
    bool sampleCollected,
  ) {
    final testId = test['_id']?.toString();
    if (status == 'assigned' && !sampleCollected) {
      return AnimatedButton(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.science, size: 16),
          label: const Text('Collect'),
          onPressed: testId != null && testId.isNotEmpty
              ? () => _collectSample(testId)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.secondaryTeal,
          ),
        ),
      );
    } else if (status == 'collected' || status == 'in_progress') {
      return AnimatedButton(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.upload, size: 16),
          label: const Text('Upload'),
          onPressed: testId != null && testId.isNotEmpty
              ? () => _showUploadResultDialog(test)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
          ),
        ),
      );
    } else if (status == 'completed') {
      return const Icon(Icons.check_circle, color: AppTheme.successGreen);
    }
    return null;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'urgent':
        return AppTheme.errorRed;
      case 'assigned':
        return AppTheme.primaryBlue;
      case 'collected':
        return AppTheme.secondaryTeal;
      case 'in_progress':
        return AppTheme.warningYellow;
      case 'completed':
        return AppTheme.successGreen;
      default:
        return AppTheme.textLight;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'urgent':
        return Icons.priority_high;
      case 'assigned':
        return Icons.assignment;
      case 'collected':
        return Icons.science;
      case 'in_progress':
        return Icons.pending;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildEnhancedHeroMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = ResponsiveUtils.getResponsiveIconSize(context, 24);
        final labelFontSize = ResponsiveUtils.getResponsiveFontSize(
          context,
          14,
        );
        final valueFontSize = ResponsiveUtils.getResponsiveFontSize(
          context,
          28,
        );
        final padding = ResponsiveUtils.getResponsiveSpacing(context, 24);
        final iconPadding = ResponsiveUtils.getResponsiveSpacing(context, 10);

        return Container(
          width: 200,
          padding: EdgeInsets.all(padding),
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
                    padding: EdgeInsets.all(iconPadding),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: iconSize),
                  ),
                  SizedBox(
                    width: ResponsiveUtils.getResponsiveSpacing(context, 16),
                  ),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: labelFontSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: ResponsiveUtils.getResponsiveSpacing(context, 16),
              ),
              SelectableText(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(
                height: ResponsiveUtils.getResponsiveSpacing(context, 8),
              ),
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
      },
    );
  }

  void _showNotificationsDialog() async {
    try {
      final authProvider = Provider.of<StaffAuthProvider>(
        context,
        listen: false,
      );
      final response = await StaffApiService.getNotifications(
        authProvider.staffId ?? '',
      );
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
              Text('Notifications ($total)'),
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
                                        '/staff/notifications/${authProvider.staffId}/${notification['_id']?.toString() ?? ''}/read',
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
                                      '/staff/notifications/${authProvider.staffId}/${notification['_id']?.toString() ?? ''}/read',
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
