import 'package:flutter/material.dart';
import '../../services/owner_api_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../config/theme.dart';

class OwnerProfileScreen extends StatefulWidget {
  const OwnerProfileScreen({super.key});

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  bool _isLoading = true;
  bool _isEditing = false;
  Map<String, dynamic>? _profileData;

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _labNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _labNameController.dispose();
    _usernameController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await OwnerApiService.getProfile();
      setState(() {
        _profileData = profile;
        _firstNameController.text = profile['name']?['first'] ?? '';
        _middleNameController.text = profile['name']?['middle'] ?? '';
        _lastNameController.text = profile['name']?['last'] ?? '';
        _emailController.text = profile['email'] ?? '';
        _phoneController.text = profile['phone_number'] ?? '';
        _labNameController.text = profile['lab_name'] ?? '';
        _usernameController.text = profile['username'] ?? '';
        _streetController.text = profile['address']?['street'] ?? '';
        _cityController.text = profile['address']?['city'] ?? '';
        _countryController.text = profile['address']?['country'] ?? 'Palestine';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  Future<void> _updateProfile() async {
    try {
      final data = {
        'name': {
          'first': _firstNameController.text,
          'middle': _middleNameController.text,
          'last': _lastNameController.text,
        },
        'email': _emailController.text,
        'phone_number': _phoneController.text,
        'lab_name': _labNameController.text,
        'username': _usernameController.text,
        'address': {
          'street': _streetController.text,
          'city': _cityController.text,
          'country': _countryController.text,
        },
      };

      final response = await OwnerApiService.updateProfile(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Profile updated successfully',
            ),
          ),
        );
        setState(() => _isEditing = false);
        _loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isEditing && !_isLoading)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => _isEditing = false);
                _loadProfile();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primaryBlue,
                    child: Text(
                      _firstNameController.text.isNotEmpty
                          ? _firstNameController.text[0].toUpperCase()
                          : 'O',
                      style: const TextStyle(fontSize: 40, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personal Information',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _firstNameController,
                            label: 'First Name',
                            prefixIcon: Icons.person,
                            enabled: _isEditing,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _middleNameController,
                            label: 'Middle Name',
                            prefixIcon: Icons.person_outline,
                            enabled: _isEditing,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _lastNameController,
                            label: 'Last Name',
                            prefixIcon: Icons.person_outline,
                            enabled: _isEditing,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _emailController,
                            label: 'Email',
                            prefixIcon: Icons.email,
                            enabled: _isEditing,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _usernameController,
                            label: 'Username',
                            prefixIcon: Icons.account_circle,
                            enabled: _isEditing,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Username is required';
                              }
                              if (value.length < 3) {
                                return 'Username must be at least 3 characters';
                              }
                              if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(value)) {
                                return 'Username can only contain lowercase letters, numbers, dots, underscores, and hyphens';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            prefixIcon: Icons.phone,
                            enabled: _isEditing,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Change Password',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'For security purposes, please change your password after your first login.',
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _showChangePasswordDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Change Password'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Laboratory Information',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _labNameController,
                            label: 'Lab Name',
                            prefixIcon: Icons.science,
                            enabled: _isEditing,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Address',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _streetController,
                            label: 'Street',
                            prefixIcon: Icons.location_on,
                            enabled: _isEditing,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _cityController,
                            label: 'City',
                            prefixIcon: Icons.location_city,
                            enabled: _isEditing,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _countryController,
                            label: 'Country',
                            prefixIcon: Icons.flag,
                            enabled: _isEditing,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_isEditing)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Information',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            _buildInfoRow(
                              'Username',
                              _profileData?['username'] ?? 'N/A',
                            ),
                            _buildInfoRow(
                              'Status',
                              _profileData?['status'] ?? 'N/A',
                            ),
                            if (_profileData?['approved_by'] != null)
                              _buildInfoRow(
                                'Approved By',
                                _profileData!['approved_by']['username'] ??
                                    'N/A',
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (_isEditing)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _updateProfile,
                        child: const Text('Save Changes'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPasswordController,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _currentPasswordController.clear();
              _newPasswordController.clear();
              _confirmPasswordController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _changePassword,
            child: const Text('Change Password'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All fields are required')));
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New password must be at least 6 characters'),
        ),
      );
      return;
    }

    try {
      final response = await OwnerApiService.changePassword(
        currentPassword,
        newPassword,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Password changed successfully',
            ),
          ),
        );

        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error changing password: $e')));
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
