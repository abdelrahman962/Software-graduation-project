import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../services/owner_api_service.dart';
import '../../config/theme.dart';
import '../../widgets/animations.dart';
import '../../widgets/confirmation_dialog.dart';
import 'owner_sidebar.dart';

class OwnerDoctorsScreen extends StatefulWidget {
  const OwnerDoctorsScreen({super.key});

  @override
  State<OwnerDoctorsScreen> createState() => _OwnerDoctorsScreenState();
}

class _OwnerDoctorsScreenState extends State<OwnerDoctorsScreen> {
  List<Map<String, dynamic>> _doctors = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _doctorSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  @override
  void dispose() {
    _doctorSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);

    try {
      final response = await OwnerApiService.getDoctors();
      setState(() {
        _doctors = List<Map<String, dynamic>>.from(response['doctors'] ?? []);
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load doctors: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showDoctorDialog([Map<String, dynamic>? doctor]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DoctorDialog(doctor: doctor),
    );

    if (result != null) {
      await _loadDoctors();
    }
  }

  Future<void> _deleteDoctor(String doctorId) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Delete Doctor',
      message:
          'Are you sure you want to delete this doctor? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );

    if (confirmed) {
      try {
        await OwnerApiService.deleteDoctor(doctorId);
        await _loadDoctors();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Doctor deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete doctor: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Doctors Management'),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showDoctorDialog(),
            ),
          ],
        ),
        drawer: const Drawer(child: OwnerSidebar()),
        body: _buildContent(context, isMobile),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          const OwnerSidebar(),
          Expanded(child: _buildContent(context, isMobile)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isMobile) {
    return Column(
      children: [
        ...(isMobile
            ? []
            : [
                Container(
                  width: double.infinity,
                  color: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(
                    vertical: 40,
                    horizontal: 20,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Doctors Management',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Manage your laboratory doctors',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ]),
        Expanded(
          child: Container(
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
                            fillColor: Colors.white,
                          ),
                          onChanged: (value) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _showDoctorDialog(),
                        icon: const Icon(Icons.add),
                        label: Text(isMobile ? 'Add' : 'Add Doctor'),
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
                                  'Error: $_error',
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadDoctors,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _buildDoctorsGrid(isMobile),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorsGrid(bool isMobile) {
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

    if (filteredDoctors.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.medical_services_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No doctors found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showDoctorDialog(),
              child: const Text('Add First Doctor'),
            ),
          ],
        ),
      );
    }

    int columns = isMobile ? 1 : 2;
    return ListView.builder(
      itemCount: (filteredDoctors.length / columns).ceil(),
      itemBuilder: (context, rowIndex) {
        int startIndex = rowIndex * columns;
        List<Widget> rowItems = [];
        for (int i = 0; i < columns; i++) {
          int itemIndex = startIndex + i;
          if (itemIndex < filteredDoctors.length) {
            rowItems.add(
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _buildDoctorCard(filteredDoctors[itemIndex], isMobile),
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

  Widget _buildDoctorCard(Map<String, dynamic> doctor, bool isMobile) {
    final fullName =
        '${doctor['name']?['first'] ?? ''} ${doctor['name']?['last'] ?? ''}'
            .trim();
    final email = doctor['email'] ?? 'N/A';
    final specialization = doctor['specialization'] ?? 'General';
    final licenseNumber = doctor['license_number'] ?? 'N/A';
    final isActive = doctor['is_active'] ?? true;

    return AnimatedCard(
      onTap: () => _showDoctorDialog(doctor),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? Colors.grey.withValues(alpha: 0.2)
                : Colors.red.withValues(alpha: 0.3),
            width: isActive ? 1 : 2,
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.medical_services,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isNotEmpty ? fullName : 'Unknown Doctor',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'License: $licenseNumber',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showDoctorDialog(doctor);
                        break;
                      case 'delete':
                        _deleteDoctor(doctor['_id']);
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Specialization: $specialization',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!isActive) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'INACTIVE',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DoctorDialog extends StatefulWidget {
  final Map<String, dynamic>? doctor;

  const _DoctorDialog({this.doctor});

  @override
  State<_DoctorDialog> createState() => _DoctorDialogState();
}

class _DoctorDialogState extends State<_DoctorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _specializationController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.doctor != null) {
      final doctor = widget.doctor!;
      _firstNameController.text = doctor['name']?['first'] ?? '';
      _lastNameController.text = doctor['name']?['last'] ?? '';
      _emailController.text = doctor['email'] ?? '';
      _licenseNumberController.text = doctor['license_number'] ?? '';
      _specializationController.text = doctor['specialization'] ?? '';
      _isActive = doctor['is_active'] ?? true;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _licenseNumberController.dispose();
    _specializationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': {
          'first': _firstNameController.text.trim(),
          'last': _lastNameController.text.trim(),
        },
        'email': _emailController.text.trim(),
        'license_number': _licenseNumberController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'is_active': _isActive,
        if (_passwordController.text.isNotEmpty)
          'password': _passwordController.text,
      };

      if (widget.doctor != null) {
        await OwnerApiService.updateDoctor(widget.doctor!['_id'], data);
      } else {
        await OwnerApiService.createDoctor(data);
      }

      if (mounted) {
        Navigator.of(context).pop(data);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.doctor != null
                  ? 'Doctor updated successfully'
                  : 'Doctor added successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save doctor: $e')));
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
      title: Text(widget.doctor != null ? 'Edit Doctor' : 'Add Doctor'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name *',
                  hintText: 'Enter first name',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'First name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name *',
                  hintText: 'Enter last name',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Last name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  hintText: 'Enter email address',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Email is required';
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value!)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _licenseNumberController,
                decoration: const InputDecoration(
                  labelText: 'License Number *',
                  hintText: 'Enter medical license number',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'License number is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _specializationController,
                decoration: const InputDecoration(
                  labelText: 'Specialization',
                  hintText: 'Enter medical specialization',
                ),
              ),
              const SizedBox(height: 16),
              if (widget.doctor != null) ...[
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password (optional)',
                    hintText: 'Leave empty to keep current password',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
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
              : Text(widget.doctor != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
