// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/owner_auth_provider.dart';
import '../../services/owner_api_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/data_table_widget.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/loading_dialog.dart';

class DoctorManagementScreen extends StatefulWidget {
  const DoctorManagementScreen({super.key});

  @override
  State<DoctorManagementScreen> createState() => _DoctorManagementScreenState();
}

class _DoctorManagementScreenState extends State<DoctorManagementScreen> {
  List<Map<String, dynamic>> _doctors = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);
    try {
      final response = await OwnerApiService.getDoctors();

      if (response['doctors'] != null) {
        setState(() {
          _doctors = List<Map<String, dynamic>>.from(response['doctors']);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to load doctors. Please check your connection or login status.',
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

  Future<void> _showDoctorDialog([Map<String, dynamic>? doctor]) async {
    final firstNameController = TextEditingController(
      text: doctor?['full_name']?['first'],
    );
    final lastNameController = TextEditingController(
      text: doctor?['full_name']?['last'],
    );
    final emailController = TextEditingController(text: doctor?['email']);
    final phoneController = TextEditingController(text: doctor?['phone']);
    final usernameController = TextEditingController(text: doctor?['username']);
    final specialtyController = TextEditingController(
      text: doctor?['specialty'],
    );
    final licenseController = TextEditingController(
      text: doctor?['license_number'],
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(doctor == null ? 'Add Doctor' : 'Edit Doctor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                controller: firstNameController,
                label: 'First Name',
                prefixIcon: Icons.person,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: lastNameController,
                label: 'Last Name',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: emailController,
                label: 'Email',
                prefixIcon: Icons.email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: phoneController,
                label: 'Phone',
                prefixIcon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: usernameController,
                label: 'Username',
                prefixIcon: Icons.account_circle,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: specialtyController,
                label: 'Specialty',
                prefixIcon: Icons.medical_services,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: licenseController,
                label: 'License Number',
                prefixIcon: Icons.card_membership,
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
              if (firstNameController.text.isEmpty ||
                  emailController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('First name and email are required'),
                  ),
                );
                return;
              }

              LoadingDialog.show(context);
              try {
                final data = {
                  'full_name': {
                    'first': firstNameController.text,
                    'last': lastNameController.text,
                  },
                  'email': emailController.text,
                  'phone': phoneController.text,
                  'username': usernameController.text,
                  'specialty': specialtyController.text,
                  'license_number': licenseController.text,
                };

                final response = doctor == null
                    ? await OwnerApiService.createDoctor(data)
                    : await OwnerApiService.updateDoctor(doctor['_id'], data);

                if (!context.mounted) return;
                LoadingDialog.hide(context);

                if (response['message'] != null) {
                  if (!context.mounted) return;
                  Navigator.pop(context);
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
    );
  }

  Future<void> _deleteDoctor(String doctorId) async {
    final confirm = await ConfirmationDialog.show(
      context,
      title: 'Delete Doctor',
      message: 'Are you sure you want to delete this doctor?',
      confirmText: 'Delete',
      confirmColor: Colors.red,
      icon: Icons.delete,
    );

    if (!confirm) return;

    if (!context.mounted) return;
    LoadingDialog.show(context);
    try {
      final response = await OwnerApiService.deleteDoctor(doctorId);

      if (!context.mounted) return;
      LoadingDialog.hide(context);

      if (response['message'] != null) {
        _loadDoctors();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doctor deleted successfully')),
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
        title: const Text('Doctor Management'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total Doctors: ${_doctors.length}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                CustomButton(
                  text: 'Add Doctor',
                  icon: Icons.add,
                  onPressed: () => _showDoctorDialog(),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : DataTableWidget(
                    columns: const ['Name', 'Email', 'Specialty', 'Status'],
                    rows: _doctors
                        .map(
                          (d) => {
                            'name':
                                '${d['full_name']?['first'] ?? ''} ${d['full_name']?['last'] ?? ''}'
                                    .trim(),
                            'email': d['email'],
                            'specialty': d['specialty'] ?? '-',
                            'status': StatusBadge(
                              status: d['status'] ?? 'active',
                              small: true,
                            ),
                            '_id': d['_id'],
                            '_data': d,
                          },
                        )
                        .toList(),
                    actions: (row) => [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showDoctorDialog(row['_data']),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteDoctor(row['_id']),
                        tooltip: 'Delete',
                      ),
                    ],
                    emptyMessage: 'No doctors found. Add your first doctor!',
                  ),
          ),
        ],
      ),
    );
  }
}
