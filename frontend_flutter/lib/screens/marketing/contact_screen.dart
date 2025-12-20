import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/common/navbar.dart';
import '../../widgets/common/footer.dart';
import '../../widgets/animations.dart';
import '../../providers/marketing_provider.dart';
import '../../services/public_api_service.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _labNameController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Load admin contact information when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MarketingProvider>().loadAdminContactInfo();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _labNameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        await PublicApiService.submitContactForm(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.isNotEmpty
              ? _phoneController.text.trim()
              : null,
          labName: _labNameController.text.trim(),
          message: _messageController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thank you! We will contact you soon.'),
              backgroundColor: Colors.green,
            ),
          );
          _formKey.currentState!.reset();
          _nameController.clear();
          _emailController.clear();
          _phoneController.clear();
          _labNameController.clear();
          _messageController.clear();
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send message: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool useMobileLayout = context.useMobileLayout;
    return Consumer<MarketingProvider>(
      builder: (context, marketingProvider, child) {
        return Scaffold(
          appBar: const PreferredSize(
            preferredSize: Size.fromHeight(68),
            child: AppNavBar(),
          ),
          endDrawer: useMobileLayout ? const MobileDrawer() : null,
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Debug width (optional)
                /*
                Container(
                  color: Colors.amber.shade100,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Center(
                    child: Text(
                      'Width: ${MediaQuery.of(context).size.width.toStringAsFixed(0)} px',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                */
                AppAnimations.fadeIn(_buildHeader(context, useMobileLayout)),
                AppAnimations.fadeIn(
                  _buildContactSection(
                    context,
                    useMobileLayout,
                    marketingProvider,
                  ),
                  delay: 200.ms,
                ),
                AppAnimations.fadeIn(const AppFooter(), delay: 400.ms),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isMobile ? 60 : 100,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              'Get Started with MedLab System',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isMobile ? 32 : 48,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          AppAnimations.fadeIn(
            Text(
              'Contact our team to discuss implementing MedLab System in your laboratory. We\'ll help you get started with a customized solution.',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: isMobile ? 16 : 20,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            delay: 300.ms,
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection(
    BuildContext context,
    bool isMobile,
    MarketingProvider marketingProvider,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isMobile ? 60 : 100,
      ),
      child: isMobile
          ? Column(
              children: [
                _buildContactForm(context),
                const SizedBox(height: 60),
                _buildContactInfo(context, marketingProvider),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildContactForm(context)),
                const SizedBox(width: 60),
                Expanded(
                  flex: 2,
                  child: _buildContactInfo(context, marketingProvider),
                ),
              ],
            ),
    );
  }

  Widget _buildContactForm(BuildContext context) {
    return Column(
      children: [
        // Registration CTA
        AppAnimations.fadeIn(
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.business_center,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ready to Register Your Laboratory?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Complete our registration form and get started with MedLab System',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    context.push('/register-owner');
                  },
                  icon: const Icon(Icons.app_registration),
                  label: const Text('Register Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),

        // Contact Form
        AnimatedCard(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppAnimations.fadeIn(
                    Text(
                      'Or Contact Us for More Information',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 32),
                  AppAnimations.slideInFromLeft(
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    delay: 200.ms,
                  ),
                  const SizedBox(height: 20),
                  AppAnimations.slideInFromRight(
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address *',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    delay: 400.ms,
                  ),
                  const SizedBox(height: 20),
                  AppAnimations.slideInFromLeft(
                    TextFormField(
                      controller: _labNameController,
                      decoration: const InputDecoration(
                        labelText: 'Laboratory Name *',
                        prefixIcon: Icon(Icons.business),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your laboratory name';
                        }
                        return null;
                      },
                    ),
                    delay: 600.ms,
                  ),
                  const SizedBox(height: 20),
                  AppAnimations.slideInFromRight(
                    TextFormField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        labelText: 'Tell us about your needs *',
                        prefixIcon: Icon(Icons.message),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please tell us about your needs';
                        }
                        return null;
                      },
                    ),
                    delay: 800.ms,
                  ),
                  const SizedBox(height: 32),
                  AppAnimations.scaleIn(
                    SizedBox(
                      width: double.infinity,
                      child: AnimatedButton(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Send Message',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ),
                    delay: 1000.ms,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactInfo(
    BuildContext context,
    MarketingProvider marketingProvider,
  ) {
    final adminContact = marketingProvider.adminContact;
    final isLoading = marketingProvider.isContactLoading;
    final error = marketingProvider.contactError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppAnimations.fadeIn(
          Text(
            'Contact Information',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 32),
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (error != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              'Unable to load contact information. Please try again later.',
              style: TextStyle(color: Colors.red.shade700),
            ),
          )
        else if (adminContact != null)
          Column(
            children: [
              AppAnimations.slideInFromLeft(
                _buildInfoItem(
                  context,
                  Icons.email,
                  'Email',
                  adminContact['email'] ?? 'contact@medlabsystem.com',
                ),
              ),
              const SizedBox(height: 24),
              AppAnimations.slideInFromRight(
                _buildInfoItem(
                  context,
                  Icons.phone,
                  'Phone',
                  adminContact['phone'] ?? '+1 (555) 123-4567',
                ),
                delay: 200.ms,
              ),
              const SizedBox(height: 24),
              AppAnimations.slideInFromLeft(
                _buildInfoItem(
                  context,
                  Icons.person,
                  'Contact Person',
                  adminContact['name'] ?? 'Medical Lab System',
                ),
                delay: 400.ms,
              ),
            ],
          )
        else
          // Fallback to default contact info if no data loaded
          Column(
            children: [
              AppAnimations.slideInFromLeft(
                _buildInfoItem(
                  context,
                  Icons.email,
                  'Email',
                  'contact@medlabsystem.com',
                ),
              ),
              const SizedBox(height: 24),
              AppAnimations.slideInFromRight(
                _buildInfoItem(
                  context,
                  Icons.phone,
                  'Phone',
                  '+1 (555) 123-4567',
                ),
                delay: 200.ms,
              ),
              const SizedBox(height: 24),
              AppAnimations.slideInFromLeft(
                _buildInfoItem(
                  context,
                  Icons.person,
                  'Contact Person',
                  'Medical Lab System',
                ),
                delay: 400.ms,
              ),
            ],
          ),
        const SizedBox(height: 24),
        AppAnimations.slideInFromRight(
          _buildInfoItem(
            context,
            Icons.location_on,
            'Address',
            '123 Medical Center Drive\nHealthcare District\nCity, State 12345',
          ),
          delay: 600.ms,
        ),
        const SizedBox(height: 24),
        AppAnimations.slideInFromRight(
          _buildInfoItem(
            context,
            Icons.access_time,
            'Business Hours',
            'Monday - Friday: 9:00 AM - 6:00 PM\nSaturday: 10:00 AM - 4:00 PM\nSunday: Closed',
          ),
          delay: 800.ms,
        ),
      ],
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    IconData icon,
    String title,
    String content,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
