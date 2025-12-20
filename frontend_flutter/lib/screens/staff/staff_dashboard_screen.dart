// ignore_for_file: use_build_context_synchronously

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/staff_auth_provider.dart';
import '../../services/staff_api_service.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/paginated_list.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'staff_sidebar.dart';
import '../../widgets/system_feedback_form.dart';
import '../../widgets/new_order_form.dart';
import 'staff_profile_screen.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _assignedTests;
  Map<String, dynamic>? _pendingOrders;
  Map<String, dynamic>? _allResultsForUpload;
  Map<String, dynamic>? _allLabTests;
  List<Map<String, dynamic>>? _dropdownInventoryItems;
  bool _isTestsLoading = false;
  bool _isOrdersLoading = false;
  bool _isResultsForUploadLoading = false;
  bool _isLabTestsLoading = false;

  // Orders data
  Map<String, dynamic>? _allOrders;
  bool _isAllOrdersLoading = false;
  String? _selectedStatus;
  String? _selectedDeviceId;
  late TabController _tabController;
  String _inventorySearchQuery = '';

  // Sidebar state
  int _selectedIndex = 0;
  bool _isSidebarOpen = true;
  bool _hasFeedbackSubmitted = false;
  bool _showFeedbackReminder = true;

  // Current staff info
  String? _currentStaffId;

  // Controllers for result upload
  final TextEditingController _resultController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

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
    // Get current staff ID from auth provider
    final authProvider = Provider.of<StaffAuthProvider>(context, listen: false);
    _currentStaffId = authProvider.user?.id;

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

  Future<void> _loadOrdersInBackground() async {
    if (_isAllOrdersLoading) return;
    setState(() => _isAllOrdersLoading = true);

    try {
      final response = await StaffApiService.getAllLabOrders();
      if (mounted) {
        setState(() {
          _allOrders = response;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load orders: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isAllOrdersLoading = false);
      }
    }
  }

  Future<void> _loadResultsForUpload() async {
    if (_isResultsForUploadLoading) return;
    setState(() => _isResultsForUploadLoading = true);

    try {
      final response = await StaffApiService.getAllResults(
        status: 'pending', // Only get results that don't have data yet
        limit: 100, // Get more results
      );
      if (mounted) {
        setState(() {
          _allResultsForUpload = response;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load results for upload: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResultsForUploadLoading = false);
      }
    }
  }

  Future<void> _loadAllLabTests() async {
    if (_isLabTestsLoading) return;
    setState(() => _isLabTestsLoading = true);

    try {
      final response = await StaffApiService.getLabTests();
      if (mounted) {
        setState(() {
          _allLabTests = response;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load lab tests: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLabTestsLoading = false);
      }
    }
  }

  Future<void> _loadAllOrders() async {
    if (_isAllOrdersLoading) return;
    setState(() => _isAllOrdersLoading = true);

    try {
      final response = await StaffApiService.getAllLabOrders();
      if (mounted) {
        setState(() {
          _allOrders = response;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load orders: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isAllOrdersLoading = false);
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

      // Filter results based on search query
      List<dynamic> allItems = response['data'] ?? [];
      List<dynamic> filteredItems = allItems;

      if (_inventorySearchQuery.isNotEmpty) {
        filteredItems = allItems.where((item) {
          final name = (item['name'] as String? ?? '').toLowerCase();
          final itemCode = (item['item_code'] as String? ?? '').toLowerCase();
          final query = _inventorySearchQuery.toLowerCase();
          return name.contains(query) || itemCode.contains(query);
        }).toList();
      }

      return {
        'data': filteredItems,
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
    try {
      final response = await StaffApiService.collectSample(detailId: detailId);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] ?? 'Sample collected successfully',
              ),
              backgroundColor: AppTheme.successGreen,
            ),
          );
          // Refresh orders to show updated status
          _loadOrdersInBackground();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to collect sample'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error collecting sample: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _showUploadResultDialog(Map<String, dynamic> test) async {
    // First, check if this test has components
    bool isLoadingComponents = true;
    List<Map<String, dynamic>> components = [];
    bool hasComponents = false;

    // Controllers for components
    final Map<String, TextEditingController> componentControllers = {};
    final Map<String, TextEditingController> componentRemarksControllers = {};

    // Controllers for single-value test
    final resultController = TextEditingController();
    final remarksController = TextEditingController();

    // Get test_id from the test data
    final testId =
        test['test_id']?['_id']?.toString() ??
        test['test_id']?.toString() ??
        '';

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Load components on first build
          if (isLoadingComponents && testId.isNotEmpty) {
            StaffApiService.getTestComponents(testId)
                .then((response) {
                  if (response['has_components'] == true &&
                      response['components'] != null) {
                    setDialogState(() {
                      components = List<Map<String, dynamic>>.from(
                        response['components'],
                      );
                      hasComponents = components.isNotEmpty;
                      isLoadingComponents = false;

                      // Create controllers for each component
                      for (var comp in components) {
                        final compId = comp['_id'].toString();
                        componentControllers[compId] = TextEditingController();
                        componentRemarksControllers[compId] =
                            TextEditingController();
                      }
                    });
                  } else {
                    setDialogState(() {
                      hasComponents = false;
                      isLoadingComponents = false;
                    });
                  }
                })
                .catchError((e) {
                  setDialogState(() {
                    hasComponents = false;
                    isLoadingComponents = false;
                  });
                });
          }

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.upload_file, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upload Result',
                        style: TextStyle(fontSize: 18),
                      ),
                      Text(
                        test['test_name'] as String? ?? 'Unknown Test',
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
            content: SingleChildScrollView(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: isLoadingComponents
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Checking test configuration...'),
                        ],
                      )
                    : hasComponents
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'This test has ${components.length} components. Enter values for each:',
                                    style: TextStyle(
                                      color: Colors.blue[900],
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...components.asMap().entries.map((entry) {
                            final index = entry.key;
                            final comp = entry.value;
                            final compId = comp['_id'].toString();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.blue[100],
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue[900],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            comp['component_name'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        if (comp['component_code'] != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              comp['component_code'],
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        if (comp['units'] != null)
                                          Text(
                                            'Units: ${comp['units']}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (comp['reference_range'] != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Normal Range: ${comp['reference_range']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: componentControllers[compId],
                                      decoration: const InputDecoration(
                                        labelText: 'Value *',
                                        hintText: 'Enter measured value',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller:
                                          componentRemarksControllers[compId],
                                      decoration: const InputDecoration(
                                        labelText: 'Remarks (Optional)',
                                        hintText: 'Notes for this component',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      maxLines: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          TextField(
                            controller: remarksController,
                            decoration: const InputDecoration(
                              labelText: 'Overall Remarks (Optional)',
                              hintText: 'General notes about the result',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      )
                    : Column(
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
                onPressed: () {
                  // Dispose controllers
                  for (var controller in componentControllers.values) {
                    controller.dispose();
                  }
                  for (var controller in componentRemarksControllers.values) {
                    controller.dispose();
                  }
                  resultController.dispose();
                  remarksController.dispose();
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoadingComponents
                    ? null
                    : () async {
                        // Validation
                        if (hasComponents) {
                          // Check if all component values are filled
                          bool allFilled = componentControllers.values.every(
                            (controller) => controller.text.isNotEmpty,
                          );
                          if (!allFilled) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter values for all components',
                                ),
                                backgroundColor: AppTheme.errorRed,
                              ),
                            );
                            return;
                          }
                        } else {
                          // Single-value test
                          if (resultController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a result value'),
                                backgroundColor: AppTheme.errorRed,
                              ),
                            );
                            return;
                          }
                        }

                        // Dispose controllers
                        for (var controller in componentControllers.values) {
                          controller.dispose();
                        }
                        for (var controller
                            in componentRemarksControllers.values) {
                          controller.dispose();
                        }
                        resultController.dispose();
                        remarksController.dispose();

                        Navigator.pop(dialogContext, true);

                        // Prepare data for submission

                        if (hasComponents) {
                          // Multi-component test
                          final componentValues = components.map((comp) {
                            final compId = comp['_id'].toString();
                            return {
                              'component_id': compId,
                              'component_value':
                                  componentControllers[compId]!.text,
                              if (componentRemarksControllers[compId]!
                                  .text
                                  .isNotEmpty)
                                'remarks':
                                    componentRemarksControllers[compId]!.text,
                            };
                          }).toList();

                          final response = await StaffApiService.uploadResult(
                            detailId: test['_id']?.toString() ?? '',
                            components: componentValues,
                            remarks: remarksController.text.isEmpty
                                ? null
                                : remarksController.text,
                          );

                          if (context.mounted) {
                            if (response['success'] != false) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    response['urgent'] == true
                                        ? '⚠️ Result uploaded - Marked as URGENT'
                                        : 'Result uploaded successfully',
                                  ),
                                  backgroundColor: response['urgent'] == true
                                      ? Colors.orange
                                      : AppTheme.successGreen,
                                ),
                              );
                              _loadAssignedTests();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    response['message'] ??
                                        'Failed to upload result',
                                  ),
                                  backgroundColor: AppTheme.errorRed,
                                ),
                              );
                            }
                          }
                        } else {
                          // Single-value test
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
                                SnackBar(
                                  content: Text(
                                    response['urgent'] == true
                                        ? '⚠️ Result uploaded - Marked as URGENT'
                                        : 'Result uploaded successfully',
                                  ),
                                  backgroundColor: response['urgent'] == true
                                      ? Colors.orange
                                      : AppTheme.successGreen,
                                ),
                              );
                              _loadAssignedTests();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    response['message'] ??
                                        'Failed to upload result',
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
          );
        },
      ),
    );
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
                  // WORKSTATION Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Text(
                      'WORKSTATION',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textLight,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _buildDrawerItem('Dashboard', Icons.dashboard, 0),
                  _buildDrawerItem('New Order', Icons.add_box, 1),
                  _buildDrawerItem('Orders', Icons.assignment, 2),
                  _buildDrawerItem('My Tests', Icons.assignment, 3),
                  _buildDrawerItem('Sample Collection', Icons.science, 4),
                  _buildDrawerItem('Result Upload', Icons.upload_file, 5),

                  // OPERATIONS Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Text(
                      'OPERATIONS',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textLight,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _buildDrawerItem('Inventory', Icons.inventory, 6),
                  _buildDrawerItem('Notifications', Icons.notifications, 7),

                  // ACCOUNT Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Text(
                      'ACCOUNT',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textLight,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  _buildDrawerItem('My Profile', Icons.person, 8),
                  _buildDrawerItem('Logout', Icons.logout, -1, isLogout: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    String title,
    IconData icon,
    int index, {
    bool isLogout = false,
  }) {
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
          onTap: () async {
            if (isLogout) {
              final authProvider = Provider.of<StaffAuthProvider>(
                context,
                listen: false,
              );
              await authProvider.logout();
              if (context.mounted) {
                context.go('/');
              }
            } else {
              setState(() => _selectedIndex = index);
              Navigator.pop(context); // Close drawer
            }
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
        return _buildNewOrderView();
      case 2:
        return _buildOrdersView();
      case 3:
        return _buildMyTestsView();
      case 4:
        return _buildSampleCollectionView();
      case 5:
        return _buildResultUploadView();
      case 6:
        return _buildInventoryView();
      case 7:
        return _buildNotificationsView();
      case 8:
        return const StaffProfileScreen();
      default:
        return _buildDashboardView();
    }
  }

  Widget _buildNotificationsView() {
    return const Center(child: Text('Notifications view coming soon'));
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

  Widget _buildNewOrderView() {
    return AppAnimations.pageDepthTransition(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create New Order',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Register walk-in patient and create order',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            NewOrderForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildMyTestsView() {
    // Load all lab tests if not already loaded
    if (_allLabTests == null && !_isLabTestsLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAllLabTests();
      });
    }

    return RefreshIndicator(
      onRefresh: _loadAllLabTests,
      child: AppAnimations.pageDepthTransition(
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAnimations.blurFadeIn(
                Row(
                  children: [
                    const Icon(
                      Icons.science,
                      color: AppTheme.primaryBlue,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'All Lab Tests',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                delay: 100.ms,
              ),
              const SizedBox(height: 16),
              AppAnimations.fadeIn(
                Text(
                  'View all tests in your lab and assign yourself to unassigned tests',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
                ),
                delay: 200.ms,
              ),
              const SizedBox(height: 24),

              // Tests List
              AppAnimations.fadeIn(_buildAllLabTestsList(), delay: 300.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersView() {
    final orders = _allOrders?['orders'] as List<dynamic>? ?? [];
    final isLoading = _isAllOrdersLoading;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(
                  Icons.assignment,
                  color: AppTheme.primaryBlue,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Lab Orders',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadAllOrders,
                  tooltip: 'Refresh Orders',
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryBlue,
                      ),
                    ),
                  )
                : orders.isEmpty
                ? Center(
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
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _buildOrderCardWithInvoice(order)
                          .animate()
                          .fadeIn(duration: 300.ms, delay: (index * 50).ms)
                          .slideY(begin: 0.1, end: 0, duration: 300.ms);
                    },
                  ),
          ),
        ],
      ),
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

  Future<void> _assignTestToMe(String detailId) async {
    try {
      final response = await StaffApiService.assignTestToMe(detailId);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                response['message'] ?? 'Test assigned successfully',
              ),
              backgroundColor: AppTheme.successGreen,
            ),
          );
          // Refresh orders to show updated assignment
          _loadOrdersInBackground();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to assign test'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning test: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _uploadResult(String detailId) async {
    // Show dialog for result input
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upload Test Result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _resultController,
              decoration: const InputDecoration(
                labelText: 'Result Value',
                hintText: 'Enter test result',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _remarksController,
              decoration: const InputDecoration(
                labelText: 'Remarks (Optional)',
                hintText: 'Additional notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_resultController.text),
            child: const Text('Upload'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final response = await StaffApiService.uploadResult(
          detailId: detailId,
          resultValue: result,
          remarks: _remarksController.text.isNotEmpty
              ? _remarksController.text
              : null,
        );

        if (response['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  response['message'] ?? 'Result uploaded successfully',
                ),
                backgroundColor: AppTheme.successGreen,
              ),
            );
            // Clear controllers
            _resultController.clear();
            _remarksController.clear();
            // Refresh orders to show updated status
            _loadOrdersInBackground();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response['message'] ?? 'Failed to upload result'),
                backgroundColor: AppTheme.errorRed,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading result: $e'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
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
      final detailId = detail['_id'];

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
            ] else ...[
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _assignTestToMe(detailId),
                icon: const Icon(Icons.person_add, size: 14),
                label: const Text('Assign to Me'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  textStyle: const TextStyle(fontSize: 10),
                  minimumSize: const Size(0, 28),
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
                (order['status'] ?? 'pending').toString().toUpperCase(),
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
      final detailId = detail['_id'];
      final status = detail['status'] ?? 'pending';
      final sampleCollected = detail['sample_collected'] ?? false;

      // Check if current staff is assigned to this test
      final isAssignedToCurrentStaff =
          assignedStaff != null && assignedStaff['_id'] == _currentStaffId;

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    testName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
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
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
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
            if (sampleCollected) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: AppTheme.successGreen,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Sample Collected',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.successGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            if (isAssignedToCurrentStaff) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (!sampleCollected &&
                      (status == 'assigned' || status == 'pending')) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _collectSample(detailId),
                        icon: const Icon(Icons.science, size: 14),
                        label: const Text('Collect Sample'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (sampleCollected &&
                      (status == 'collected' || status == 'in_progress')) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _uploadResult(detailId),
                        icon: const Icon(Icons.upload_file, size: 14),
                        label: const Text('Upload Result'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return AppTheme.primaryBlue;
      case 'collected':
        return Colors.purple;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return AppTheme.successGreen;
      case 'cancelled':
        return AppTheme.errorRed;
      default:
        return Colors.grey;
    }
  }

  Widget _buildAllLabTestsList() {
    final tests = _allLabTests?['tests'] as List<dynamic>? ?? [];

    if (_isLabTestsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tests.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No tests found in the lab'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: tests.map((test) => _buildLabTestCard(test)).toList(),
    );
  }

  Widget _buildLabTestCard(Map<String, dynamic> test) {
    final testName = test['test_name'] as String? ?? 'Unknown Test';
    final testId = test['_id']?.toString();
    final assignedStaff = test['assigned_staff'] as Map<String, dynamic>?;
    final isAssigned = assignedStaff != null;
    final assignedStaffName = isAssigned
        ? '${assignedStaff['full_name']?['first'] ?? ''} ${assignedStaff['full_name']?['last'] ?? ''}'
              .trim()
        : 'Unassigned';

    return AnimatedCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAssigned ? Icons.assignment_turned_in : Icons.assignment,
                  color: isAssigned
                      ? AppTheme.successGreen
                      : AppTheme.warningYellow,
                ),
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
                    color: isAssigned
                        ? AppTheme.successGreen.withValues(alpha: 0.2)
                        : AppTheme.warningYellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isAssigned ? 'Assigned' : 'Unassigned',
                    style: TextStyle(
                      color: isAssigned
                          ? AppTheme.successGreen
                          : AppTheme.warningYellow,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Assigned to: $assignedStaffName',
              style: TextStyle(
                color: isAssigned ? Colors.black : AppTheme.warningYellow,
                fontWeight: isAssigned ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (!isAssigned)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('Assign to Me'),
                  onPressed: testId != null && testId.isNotEmpty
                      ? () => _assignTestToMe(testId)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                  ),
                ),
              )
            else
              const Text(
                'This test is already assigned to a staff member',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
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
    // Load results for upload if not already loaded
    if (_allResultsForUpload == null && !_isResultsForUploadLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadResultsForUpload();
      });
    }

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
                'Upload test results for any test in the lab',
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
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search by item name or code...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _inventorySearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() => _inventorySearchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  setState(() => _inventorySearchQuery = value);
                },
              ),
              delay: 150.ms,
            ),
            const SizedBox(height: 16),
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
                  key: ValueKey(
                    _inventorySearchQuery,
                  ), // Force rebuild on search change
                  fetchData: _fetchInventoryPage,
                  itemBuilder: _buildInventoryItemCard,
                  emptyMessage: _inventorySearchQuery.isNotEmpty
                      ? 'No items found matching "$_inventorySearchQuery"'
                      : 'No inventory items found',
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
    final results = _allResultsForUpload?['results'] as List<dynamic>? ?? [];

    // Filter for results that don't have data yet (pending results)
    final pendingResults = results.where((result) {
      final resultData = result['result'] as Map<String, dynamic>?;
      return resultData == null || resultData.isEmpty;
    }).toList();

    if (_isResultsForUploadLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (pendingResults.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No tests ready for result upload'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: pendingResults
          .map((result) => _buildResultUploadCard(result))
          .toList(),
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

  Widget _buildResultUploadCard(Map<String, dynamic> result) {
    final test = result['test_id'] as Map<String, dynamic>?;
    final testName = test?['test_name'] as String? ?? 'Unknown Test';
    final patient = result['patient_id'] as Map<String, dynamic>?;
    final patientName = patient != null
        ? '${patient['full_name']?['first'] ?? ''} ${patient['full_name']?['last'] ?? ''}'
              .trim()
        : 'Unknown Patient';
    final order = result['order_id'] as Map<String, dynamic>?;
    final orderId = order?['_id']?.toString();
    final sampleBarcode =
        result['sample_barcode'] as String? ?? 'Not generated';
    final detailId = result['_id']?.toString();

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
                    color: AppTheme.secondaryTeal.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Ready for Upload',
                    style: TextStyle(
                      color: AppTheme.secondaryTeal,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Patient: $patientName'),
            Text('Sample Barcode: $sampleBarcode'),
            if (orderId != null)
              Text('Order: #${orderId.substring(0, 8).toUpperCase()}'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.upload),
                label: const Text('Upload Result'),
                onPressed: detailId != null && detailId.isNotEmpty
                    ? () => _showUploadResultDialog(result)
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

    // For completed tests, use ExpansionTile to show results
    if (status == 'completed') {
      return AnimatedCard(
        margin: const EdgeInsets.only(bottom: 8),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: _getStatusColor(status).withValues(alpha: 0.2),
            child: Icon(_getStatusIcon(status), color: _getStatusColor(status)),
          ),
          title: Text(testName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient: $patientName'),
              Text('Sample Barcode: $sampleBarcode'),
              if (deviceName != null) Text('Device: $deviceName'),
            ],
          ),
          children: [
            // Test Results Section
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Test Results',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _buildResultDisplay(test),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // For non-completed tests, use regular ListTile
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

  Widget _buildResultDisplay(Map<String, dynamic> test) {
    final result = test['result'] as Map<String, dynamic>?;

    if (result == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'No results available.',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      );
    }

    final hasComponents = result['has_components'] as bool? ?? false;
    final isAbnormal = result['is_abnormal'] as bool? ?? false;

    if (hasComponents) {
      // Display results with components
      final components = result['components'] as List<dynamic>? ?? [];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAbnormal)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppTheme.errorRed.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, color: AppTheme.errorRed, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Abnormal Results',
                    style: TextStyle(
                      color: AppTheme.errorRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          ...components.map((component) {
            final componentName =
                component['component_name'] as String? ?? 'Unknown';
            final value = component['component_value'] as String? ?? 'N/A';
            final units = component['units'] as String? ?? '';
            final referenceRange =
                component['reference_range'] as String? ?? '';
            final isComponentAbnormal =
                component['is_abnormal'] as bool? ?? false;
            final remarks = component['remarks'] as String? ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isComponentAbnormal
                    ? AppTheme.errorRed.withValues(alpha: 0.05)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isComponentAbnormal
                      ? AppTheme.errorRed.withValues(alpha: 0.3)
                      : Colors.grey[300]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          componentName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (isComponentAbnormal)
                        const Icon(
                          Icons.warning,
                          color: AppTheme.errorRed,
                          size: 16,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Result: $value ${units.isNotEmpty ? units : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isComponentAbnormal
                              ? AppTheme.errorRed
                              : Colors.black,
                          fontWeight: isComponentAbnormal
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  if (referenceRange.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Reference: $referenceRange',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                  if (remarks.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Remarks: $remarks',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      );
    } else {
      // Display simple result without components
      final resultValue = result['result_value'] as String? ?? 'N/A';
      final units = result['units'] as String? ?? '';
      final referenceRange = result['reference_range'] as String? ?? '';
      final remarks = result['remarks'] as String? ?? '';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAbnormal
              ? AppTheme.errorRed.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAbnormal
                ? AppTheme.errorRed.withValues(alpha: 0.3)
                : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isAbnormal)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppTheme.errorRed.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning, color: AppTheme.errorRed, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Abnormal Result',
                      style: TextStyle(
                        color: AppTheme.errorRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              'Result: $resultValue ${units.isNotEmpty ? units : ''}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isAbnormal ? AppTheme.errorRed : Colors.black,
              ),
            ),
            if (referenceRange.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Reference Range: $referenceRange',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
            if (remarks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Remarks: $remarks',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ],
        ),
      );
    }
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
