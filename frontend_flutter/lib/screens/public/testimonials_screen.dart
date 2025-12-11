import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/marketing_provider.dart';
import '../../models/feedback.dart' as feedback_model;

class TestimonialsScreen extends StatefulWidget {
  const TestimonialsScreen({super.key});

  @override
  State<TestimonialsScreen> createState() => _TestimonialsScreenState();
}

class _TestimonialsScreenState extends State<TestimonialsScreen> {
  String _selectedRole = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<MarketingProvider>(context, listen: false);
      provider.loadSystemFeedback(limit: 50, minRating: 4);
    });
  }

  List<feedback_model.Feedback> _filterFeedback(
    List<feedback_model.Feedback> allFeedback,
  ) {
    if (_selectedRole == 'All') return allFeedback;
    return allFeedback.where((f) => f.userModel == _selectedRole).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MarketingProvider>(context);
    final filteredFeedback = _filterFeedback(provider.systemFeedback);
    final roles = ['All', 'Owner', 'Staff', 'Doctor', 'Patient'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('What Our Users Say'),
        centerTitle: true,
        elevation: 2,
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.7),
                ],
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.stars, size: 48, color: Colors.white),
                const SizedBox(height: 16),
                const Text(
                  'Trusted by Lab Owners, Staff, Doctors & Patients',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Real feedback from real users across all roles',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: roles.map((role) {
                  final isSelected = _selectedRole == role;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(role),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedRole = role);
                      },
                      selectedColor: Theme.of(
                        context,
                      ).primaryColor.withOpacity(0.2),
                      checkmarkColor: Theme.of(context).primaryColor,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Statistics Bar
          if (provider.systemFeedback.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    context,
                    Icons.people,
                    filteredFeedback.length.toString(),
                    'Reviews',
                  ),
                  _buildStatItem(
                    context,
                    Icons.star,
                    _calculateAverageRating(filteredFeedback),
                    'Average',
                  ),
                  _buildStatItem(
                    context,
                    Icons.groups,
                    _countUniqueRoles(provider.systemFeedback).toString(),
                    'User Types',
                  ),
                ],
              ),
            ),

          // Testimonials List
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(provider.error!),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            provider.loadSystemFeedback(
                              limit: 50,
                              minRating: 4,
                            );
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : filteredFeedback.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.feedback_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No testimonials yet for $_selectedRole',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await provider.loadSystemFeedback(
                        limit: 50,
                        minRating: 4,
                      );
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredFeedback.length,
                      itemBuilder: (context, index) {
                        return _buildTestimonialCard(
                          context,
                          filteredFeedback[index],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildTestimonialCard(
    BuildContext context,
    feedback_model.Feedback feedback,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user role badge and rating
            Row(
              children: [
                _buildRoleBadge(feedback.userModel),
                const Spacer(),
                _buildStarRating(feedback.rating),
              ],
            ),
            const SizedBox(height: 12),

            // Feedback message
            Text(
              feedback.message ?? '',
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 12),

            // User name and date
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _getRoleColor(
                    feedback.userModel,
                  ).withOpacity(0.2),
                  child: Icon(
                    _getRoleIcon(feedback.userModel),
                    size: 16,
                    color: _getRoleColor(feedback.userModel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getUserDisplayName(feedback),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _formatDate(feedback.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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
    );
  }

  Widget _buildRoleBadge(String role) {
    final color = _getRoleColor(role);
    final icon = _getRoleIcon(role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            role,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 20,
        );
      }),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Owner':
        return Colors.purple;
      case 'Staff':
        return Colors.blue;
      case 'Doctor':
        return Colors.green;
      case 'Patient':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'Owner':
        return Icons.business;
      case 'Staff':
        return Icons.badge;
      case 'Doctor':
        return Icons.medical_services;
      case 'Patient':
        return Icons.person;
      default:
        return Icons.person_outline;
    }
  }

  String _getUserDisplayName(feedback_model.Feedback feedback) {
    if (feedback.isAnonymous) {
      return 'Anonymous ${feedback.userModel}';
    }

    if (feedback.user != null && feedback.user!['full_name'] != null) {
      final fullName = feedback.user!['full_name'];
      if (fullName['first'] != null && fullName['last'] != null) {
        return '${fullName['first']} ${fullName['last']}';
      }
    }

    if (feedback.user != null && feedback.user!['lab_name'] != null) {
      return feedback.user!['lab_name'];
    }

    if (feedback.user != null && feedback.user!['username'] != null) {
      return feedback.user!['username'];
    }

    return '${feedback.userModel} User';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  String _calculateAverageRating(List<feedback_model.Feedback> feedbacks) {
    if (feedbacks.isEmpty) return '0.0';
    final total = feedbacks.fold<int>(0, (sum, f) => sum + f.rating);
    return (total / feedbacks.length).toStringAsFixed(1);
  }

  int _countUniqueRoles(List<feedback_model.Feedback> feedbacks) {
    final roles = feedbacks.map((f) => f.userModel).toSet();
    return roles.length;
  }
}
