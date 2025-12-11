import 'package:flutter/material.dart';

class FeedbackForm extends StatefulWidget {
  final String userType; // 'patient', 'doctor', 'staff', 'owner'
  final String targetType; // 'system', 'lab', 'test', 'order', 'service'
  final String? targetId;
  final String? targetName;
  final Function(Map<String, dynamic>) onSubmit;
  final VoidCallback? onCancel;

  const FeedbackForm({
    super.key,
    required this.userType,
    required this.targetType,
    this.targetId,
    this.targetName,
    required this.onSubmit,
    this.onCancel,
  });

  @override
  State<FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<FeedbackForm> {
  int _rating = 0;
  final TextEditingController _messageController = TextEditingController();
  bool _isAnonymous = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _submitFeedback() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }

    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide feedback message')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final feedbackData = {
        'target_type': widget.targetType,
        'target_id': widget.targetId,
        'rating': _rating,
        'message': _messageController.text.trim(),
        'is_anonymous': _isAnonymous,
      };

      await widget.onSubmit(feedbackData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your feedback!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit feedback: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.feedback, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Provide Feedback',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed:
                      widget.onCancel ?? () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Help us improve by sharing your experience',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Target info (if applicable)
            if (widget.targetName != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.targetType == 'lab'
                          ? Icons.business
                          : widget.targetType == 'test'
                          ? Icons.science
                          : widget.targetType == 'order'
                          ? Icons.receipt
                          : Icons.miscellaneous_services,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTargetTypeDisplayName(widget.targetType),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            widget.targetName!,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Star Rating
            Text(
              'How would you rate?',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNumber = index + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = starNumber),
                  icon: Icon(
                    _rating >= starNumber ? Icons.star : Icons.star_border,
                    color: _rating >= starNumber ? Colors.amber : Colors.grey,
                    size: 40,
                  ),
                );
              }),
            ),
            if (_rating > 0)
              Center(
                child: Text(
                  _getRatingText(_rating),
                  style: TextStyle(
                    color: _getRatingColor(_rating),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Feedback Message
            Text(
              'Tell us more',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText:
                    'What did you like? What can we improve? Any suggestions?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),

            // Anonymous option
            CheckboxListTile(
              value: _isAnonymous,
              onChanged: (value) =>
                  setState(() => _isAnonymous = value ?? false),
              title: const Text('Submit anonymously'),
              subtitle: const Text('Your identity will not be revealed'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTargetTypeDisplayName(String targetType) {
    switch (targetType) {
      case 'lab':
        return 'Lab';
      case 'test':
        return 'Test';
      case 'order':
        return 'Order';
      case 'service':
        return 'Service';
      case 'system':
        return 'System';
      default:
        return targetType;
    }
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
      case 2:
        return Colors.red;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.blue;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
