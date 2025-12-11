import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/owner_auth_provider.dart';
import '../../services/owner_api_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/data_table_widget.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/loading_dialog.dart';

class TestManagementScreen extends StatefulWidget {
  const TestManagementScreen({super.key});

  @override
  State<TestManagementScreen> createState() => _TestManagementScreenState();
}

class _TestManagementScreenState extends State<TestManagementScreen> {
  List<Map<String, dynamic>> _tests = [];
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final testResponse = await OwnerApiService.getTests();
      final deviceResponse = await OwnerApiService.getDevices();

      if (testResponse['tests'] != null && deviceResponse['devices'] != null) {
        setState(() {
          _tests = List<Map<String, dynamic>>.from(testResponse['tests']);
          _devices = List<Map<String, dynamic>>.from(deviceResponse['devices']);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to load tests or devices. Please check your connection or login status.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showTestDialog([Map<String, dynamic>? test]) async {
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
    String? selectedDevice = test?['device_id'];

    await showDialog(
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
                DropdownButtonFormField<String>(
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
                        value: device['_id'] as String,
                        child: Text(device['name'] as String),
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
              onPressed: () => Navigator.pop(context),
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
                    if (selectedDevice != null) 'device_id': selectedDevice,
                  };

                  final response = test == null
                      ? await OwnerApiService.createTest(data)
                      : await OwnerApiService.updateTest(test['_id'], data);

                  if (!context.mounted) return;
                  LoadingDialog.hide(context);

                  if (response['message'] != null) {
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _loadData();
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
  }

  Future<void> _deleteTest(String testId) async {
    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Delete Test',
      message: 'Are you sure you want to delete this test?',
      confirmText: 'Delete',
      confirmColor: Colors.red,
      icon: Icons.delete,
    );

    if (!confirm) return;

    if (!context.mounted) return;
    LoadingDialog.show(context);
    try {
      final response = await OwnerApiService.deleteTest(testId);

      if (!context.mounted) return;
      LoadingDialog.hide(context);

      if (response['message'] != null) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test deleted successfully')),
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<OwnerAuthProvider>(context);

    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/owner/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.dashboard),
          onPressed: () => context.go('/owner/dashboard'),
          tooltip: 'Dashboard',
        ),
        title: const Text('Test Management'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total Tests: ${_tests.length}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                CustomButton(
                  text: 'Add Test',
                  icon: Icons.add,
                  onPressed: () => _showTestDialog(),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : DataTableWidget(
                    columns: const [
                      'Test Name',
                      'Test Code',
                      'Price',
                      'Turnaround',
                      'Units',
                      'Method',
                    ],
                    rows: _tests
                        .map(
                          (t) => {
                            'test_name': t['test_name'],
                            'test_code': t['test_code'] ?? '-',
                            'price': '\$${t['price']}',
                            'turnaround': '${t['turnaround_time']}h',
                            'units': t['units'] ?? '-',
                            'method': t['method'] ?? '-',
                            '_id': t['_id'],
                            '_data': t,
                          },
                        )
                        .toList(),
                    actions: (row) => [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showTestDialog(row['_data']),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteTest(row['_id']),
                        tooltip: 'Delete',
                      ),
                    ],
                    emptyMessage: 'No tests found. Add your first test!',
                  ),
          ),
        ],
      ),
    );
  }
}
