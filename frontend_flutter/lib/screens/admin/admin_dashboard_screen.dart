import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import '../../widgets/animations.dart';
import '../../config/theme.dart';
import '../../widgets/admin_sidebar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  Timer? _refreshTimer;
  int _selectedIndex = 0;
  bool _isSidebarOpen = true;
  String _labOwnersSearchQuery = '';
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        ApiService.setAuthToken(authProvider.token);
        _loadDashboardData();
        _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
          if (mounted) _loadDashboardData();
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      ApiService.setAuthToken(authProvider.token);

      final result = await ApiService.get(ApiConfig.adminDashboard);

      setState(() {
        _dashboardData = result is Map<String, dynamic> ? result : {};
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading dashboard: $e')));
      }
    }
  }

  void _handleNavigation(int index) {
    setState(() => _selectedIndex = index);

    // Handle navigation based on selected index
    switch (index) {
      case 0: // Dashboard - already handled by setState
        break;
      case 1: // Lab Owners - show in main content
        // Content shown when _selectedIndex == 1
        break;
      case 2: // Pending Approvals - show in main content
        // Content shown when _selectedIndex == 2
        break;
      case 3: // Subscriptions - show in main content
        // Content shown when _selectedIndex == 3
        break;
      case 4: // Notifications - show in main content
        // Content shown when _selectedIndex == 4
        break;
      case 5: // Feedback - show in main content
        // Content shown when _selectedIndex == 5
        break;
      case 6: // System Reports - show in main content
        // Content shown when _selectedIndex == 6
        break;
      case 7: // Settings
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings panel coming soon!')),
        );
        break;
      default:
        break;
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
    final authProvider = Provider.of<AuthProvider>(context);
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isVerySmall = MediaQuery.of(context).size.width < 500;

    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/admin/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isLoading) {
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
              title: Text(
                'Admin Dashboard',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
              title: Text(
                'Admin Dashboard',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              actions: [
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
                        Icons.admin_panel_settings,
                        color: AppTheme.primaryBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        authProvider.user?['full_name'] ??
                            authProvider.user?['username'] ??
                            'Administrator',
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
          ? AdminSidebar(
              selectedIndex: _selectedIndex,
              onItemSelected: (index) {
                Navigator.pop(context);
                _handleNavigation(index);
              },
            )
          : null,
      body: Stack(
        children: [
          Row(
            children: [
              if (!isMobile &&
                  _isSidebarOpen &&
                  MediaQuery.of(context).size.width > 600)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 280,
                  child: AdminSidebar(
                    selectedIndex: _selectedIndex,
                    onItemSelected: _handleNavigation,
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Hero Section (only on dashboard)
                      if (_selectedIndex == 0)
                        AppAnimations.blurFadeIn(
                          _buildHeroSection(context, isMobile, isVerySmall),
                        ),
                      // Activity Section
                      if (_selectedIndex == 0)
                        AppAnimations.elasticSlideIn(
                          _buildActivitySection(context, isMobile, isVerySmall),
                          delay: 500.ms,
                        ),
                      // Quick Actions Section
                      if (_selectedIndex == 0)
                        AppAnimations.elasticSlideIn(
                          _buildQuickActionsSection(
                            context,
                            isMobile,
                            isVerySmall,
                          ),
                          delay: 900.ms,
                        ),
                      // Lab Owners Section
                      if (_selectedIndex == 1)
                        AppAnimations.fadeIn(
                          _buildLabOwnersSection(
                            context,
                            isMobile,
                            isVerySmall,
                          ),
                        ),
                      // Pending Approvals Section
                      if (_selectedIndex == 2)
                        AppAnimations.fadeIn(
                          _buildPendingApprovalsSection(
                            context,
                            isMobile,
                            isVerySmall,
                          ),
                        ),
                      // Subscriptions Section
                      if (_selectedIndex == 3)
                        AppAnimations.fadeIn(
                          _buildSubscriptionsSection(
                            context,
                            isMobile,
                            isVerySmall,
                          ),
                        ),
                      // Notifications Section
                      if (_selectedIndex == 4)
                        AppAnimations.fadeIn(
                          _buildNotificationsSection(
                            context,
                            isMobile,
                            isVerySmall,
                          ),
                        ),
                      // Feedback Section
                      if (_selectedIndex == 5)
                        AppAnimations.fadeIn(
                          _buildFeedbackSection(context, isMobile, isVerySmall),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Screen Width Display
          /*
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
          */
        ],
      ),
    );
  }

  Widget _buildHeroSection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    final hasAppBar = !isMobile;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
      padding: EdgeInsets.only(
        left: isMobile ? 24 : 48,
        right: isMobile ? 24 : 48,
        top: hasAppBar
            ? (isVerySmall ? 32 : (isMobile ? 80 : 80))
            : (isVerySmall ? 48 : (isMobile ? 80 : 120)),
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
                    Icons.admin_panel_settings,
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
                        'Welcome to Admin Dashboard',
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
                          'Monitor and manage your entire medical laboratory system from one centralized dashboard',
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
                    'Total Labs',
                    '${_dashboardData?['totalLabs'] ?? 0}',
                    Icons.business,
                    AppTheme.primaryBlue,
                    isMobile,
                    isVerySmall,
                  ),
                  glowColor: AppTheme.primaryBlue,
                ),
                AppAnimations.glowPulse(
                  _buildEnhancedHeroMetric(
                    'Pending Requests',
                    '${_dashboardData?['pendingRequests'] ?? 0}',
                    Icons.pending_actions,
                    AppTheme.accentOrange,
                    isMobile,
                    isVerySmall,
                  ),
                  glowColor: AppTheme.accentOrange,
                ),
                AppAnimations.glowPulse(
                  _buildEnhancedHeroMetric(
                    'Expiring Soon',
                    '${_dashboardData?['expiringLabsCount'] ?? 0}',
                    Icons.schedule,
                    AppTheme.errorRed,
                    isMobile,
                    isVerySmall,
                  ),
                  glowColor: AppTheme.errorRed,
                ),
              ],
            ),
            delay: 600.ms,
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
    final expiringLabs = _dashboardData?['expiringLabs'] as List? ?? [];

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
          if (expiringLabs.isEmpty && _dashboardData?['pendingRequests'] == 0)
            AnimatedCard(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All systems running smoothly',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No urgent actions required at this time',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
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
                              Text(
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
                    if (_dashboardData?['pendingRequests'] != null &&
                        _dashboardData!['pendingRequests'] > 0)
                      _buildActivityItem(
                        context,
                        'Pending Lab Owner Requests',
                        '${_dashboardData!['pendingRequests']} requests awaiting approval',
                        Icons.pending_actions,
                        AppTheme.accentOrange,
                      ),
                    ...expiringLabs
                        .take(3)
                        .map(
                          (lab) => _buildActivityItem(
                            context,
                            'Subscription Expiring Soon',
                            '${lab['name']} - expires ${_formatDate(lab['subscription_end'])}',
                            Icons.warning,
                            AppTheme.errorRed,
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
    final actions = [
      {
        'title': 'Manage Labs',
        'subtitle': 'View and manage laboratory accounts',
        'icon': Icons.science,
        'color': AppTheme.primaryBlue,
        'onTap': () => _showLabOwnersDialog(context),
      },
      {
        'title': 'Review Applications',
        'subtitle': 'Process pending lab owner requests',
        'icon': Icons.pending_actions,
        'color': AppTheme.accentOrange,
        'onTap': () => _showPendingRequestsDialog(context),
      },
      {
        'title': 'Subscription Management',
        'subtitle': 'Monitor and manage subscriptions',
        'icon': Icons.payment,
        'color': AppTheme.successGreen,
        'onTap': () => _showSubscriptionsDialog(context),
      },
      {
        'title': 'System Reports',
        'subtitle': 'Generate detailed analytics reports',
        'icon': Icons.analytics,
        'color': AppTheme.secondaryTeal,
        'onTap': () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('System Reports coming soon!')),
        ),
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
            crossAxisCount: isMobile ? 1 : (isVerySmall ? 1 : 2),
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

  Widget _buildEnhancedHeroMetric(
    String label,
    String value,
    IconData icon,
    Color color,
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

  Widget _buildActivityItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  softWrap: true,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(date.toString());
      final now = DateTime.now();
      final difference = dateTime.difference(now).inDays;

      if (difference == 0) return 'today';
      if (difference == 1) return 'tomorrow';
      if (difference > 0) return 'in $difference days';
      return '${-difference} days ago';
    } catch (e) {
      return date.toString();
    }
  }

  String _formatFullDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      return date.toString();
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<dynamic> _filterLabOwners(List<dynamic> labs) {
    final query = _labOwnersSearchQuery.toLowerCase();
    if (query.isEmpty) return labs;

    return labs.where((owner) {
      final name = owner['name'];
      final displayName = name is Map
          ? '${name['first'] ?? ''} ${name['last'] ?? ''}'.trim()
          : (name?.toString() ?? '');
      final labName = owner['lab_name']?.toString() ?? '';
      final email = owner['email']?.toString() ?? '';
      final phone = owner['phone_number']?.toString() ?? '';
      final status = owner['status']?.toString() ?? '';

      return displayName.toLowerCase().contains(query) ||
          labName.toLowerCase().contains(query) ||
          email.toLowerCase().contains(query) ||
          phone.toLowerCase().contains(query) ||
          status.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildPendingApprovalsSection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    return FutureBuilder(
      future: ApiService.get(ApiConfig.adminLabOwners),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(50),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        final response = snapshot.data;
        final allLabs = response is List ? response : [];
        // Filter only pending requests
        final pendingRequests = allLabs
            .where((owner) => owner['status'] == 'pending')
            .toList();

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 80,
            vertical: isVerySmall ? 40 : (isMobile ? 60 : 80),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pending Approvals',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isVerySmall ? 24 : (isMobile ? 28 : 36),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Review and approve lab owner registration requests',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  fontSize: isVerySmall ? 14 : 16,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Total Pending Requests: ${pendingRequests.length}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentOrange,
                ),
              ),
              const SizedBox(height: 24),
              if (pendingRequests.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: AppTheme.successGreen,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No pending approval requests',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pendingRequests.length,
                      itemBuilder: (context, index) {
                        final owner = pendingRequests[index];
                        final name = owner['name'];
                        final displayName = name is Map
                            ? '${name['first'] ?? ''} ${name['last'] ?? ''}'
                                  .trim()
                            : (name?.toString() ?? 'Unknown');
                        final initial = displayName.isNotEmpty
                            ? displayName.substring(0, 1).toUpperCase()
                            : 'L';

                        // Format address
                        final address = owner['address'];
                        final addressStr = address is Map
                            ? '${address['street'] ?? ''}, ${address['city'] ?? ''}, ${address['state'] ?? ''} ${address['postal_code'] ?? ''}'
                                  .trim()
                                  .replaceAll(RegExp(r',\s*,'), ',')
                                  .replaceAll(RegExp(r'^,\s*'), '')
                                  .replaceAll(RegExp(r',\s*$'), '')
                            : 'N/A';

                        // Format dates
                        final requestDate = owner['date_subscription'] != null
                            ? _formatFullDate(owner['date_subscription'])
                            : 'N/A';

                        return AnimatedCard(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.accentOrange,
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(owner['lab_name'] ?? 'Lab'),
                            trailing: const Chip(
                              label: Text(
                                'PENDING',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: AppTheme.accentOrange,
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDetailRow(
                                      Icons.person,
                                      'Lab Owner',
                                      displayName,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDetailRow(
                                      Icons.science,
                                      'Lab Name',
                                      owner['lab_name'] ?? 'N/A',
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDetailRow(
                                      Icons.email,
                                      'Email',
                                      owner['email'] ?? 'N/A',
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDetailRow(
                                      Icons.phone,
                                      'Phone',
                                      owner['phone_number'] ?? 'N/A',
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDetailRow(
                                      Icons.location_on,
                                      'Address',
                                      addressStr,
                                    ),
                                    const Divider(height: 24),
                                    _buildDetailRow(
                                      Icons.calendar_today,
                                      'Request Date',
                                      requestDate,
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            await _approveLabOwner(
                                              owner['_id'],
                                              displayName,
                                            );
                                          },
                                          icon: const Icon(Icons.check),
                                          label: const Text('Approve'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.successGreen,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        OutlinedButton.icon(
                                          onPressed: () async {
                                            await _rejectLabOwner(
                                              owner['_id'],
                                              displayName,
                                            );
                                          },
                                          icon: const Icon(Icons.close),
                                          label: const Text('Reject'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.errorRed,
                                            side: const BorderSide(
                                              color: AppTheme.errorRed,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionsSection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    return FutureBuilder(
      future: ApiService.get(ApiConfig.adminExpiringSubscriptions),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(50),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        final response = snapshot.data as Map<String, dynamic>?;
        final labs = response?['labs'] as List? ?? [];
        final count = response?['count'] ?? 0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 80,
            vertical: isVerySmall ? 40 : (isMobile ? 60 : 80),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expiring Subscriptions',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isVerySmall ? 24 : (isMobile ? 28 : 36),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Monitor and manage laboratory subscriptions ending within 30 days',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  fontSize: isVerySmall ? 14 : 16,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Total Expiring Soon: $count',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentOrange,
                ),
              ),
              const SizedBox(height: 24),
              if (labs.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: AppTheme.successGreen,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No expiring subscriptions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All subscriptions are current',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              else
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: labs.length,
                      itemBuilder: (context, index) {
                        final lab = labs[index];
                        final name = lab['name'];
                        final displayName = name is Map
                            ? '${name['first'] ?? ''} ${name['last'] ?? ''}'
                                  .trim()
                            : (name?.toString() ?? 'Unknown Lab');
                        final initial = displayName.isNotEmpty
                            ? displayName.substring(0, 1).toUpperCase()
                            : 'L';

                        final labName = lab['lab_name'] ?? 'N/A';
                        final email = lab['email'] ?? 'N/A';
                        final phone = lab['phone_number'] ?? 'N/A';

                        final subscriptionEnd = lab['subscription_end'] != null
                            ? _formatFullDate(lab['subscription_end'])
                            : 'N/A';

                        // Calculate days remaining
                        int daysRemaining = 0;
                        if (lab['subscription_end'] != null) {
                          try {
                            final endDate = DateTime.parse(
                              lab['subscription_end'].toString(),
                            );
                            daysRemaining = endDate
                                .difference(DateTime.now())
                                .inDays;
                          } catch (e) {
                            daysRemaining = 0;
                          }
                        }

                        final isUrgent = daysRemaining <= 7;

                        return AnimatedCard(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isUrgent
                                  ? AppTheme.errorRed.withValues(alpha: 0.05)
                                  : null,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: isUrgent
                                    ? AppTheme.errorRed
                                    : AppTheme.accentOrange,
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(labName),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isUrgent
                                      ? AppTheme.errorRed
                                      : AppTheme.accentOrange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isUrgent
                                          ? Icons.error
                                          : Icons.access_time,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      daysRemaining > 0
                                          ? '$daysRemaining days'
                                          : 'Expired',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildDetailRow(
                                        Icons.person,
                                        'Lab Owner',
                                        displayName,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.science,
                                        'Lab Name',
                                        labName,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.email,
                                        'Email',
                                        email,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.phone,
                                        'Phone',
                                        phone,
                                      ),
                                      const Divider(height: 24),
                                      _buildDetailRow(
                                        Icons.event,
                                        'Subscription End Date',
                                        subscriptionEnd,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        isUrgent
                                            ? Icons.error
                                            : Icons.access_time,
                                        'Days Remaining',
                                        daysRemaining > 0
                                            ? '$daysRemaining days'
                                            : 'Expired',
                                      ),
                                      if (isUrgent) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppTheme.errorRed.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.errorRed
                                                  .withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.warning,
                                                color: AppTheme.errorRed,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  daysRemaining > 0
                                                      ? 'Urgent: Subscription expires in $daysRemaining days!'
                                                      : 'Critical: Subscription has expired!',
                                                  style: const TextStyle(
                                                    color: AppTheme.errorRed,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Renew subscription for $displayName coming soon',
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.refresh),
                                            label: const Text('Renew'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.successGreen,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Contact $displayName: $email',
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.email),
                                            label: const Text('Contact'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AppTheme.primaryBlue,
                                              side: const BorderSide(
                                                color: AppTheme.primaryBlue,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabOwnersSection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    return FutureBuilder(
      future: ApiService.get(ApiConfig.adminLabOwners),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(50),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        final response = snapshot.data;
        final labs = response is List ? response : [];

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 80,
            vertical: isVerySmall ? 40 : (isMobile ? 60 : 80),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Laboratory Owners',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isVerySmall ? 24 : (isMobile ? 28 : 36),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage and view all registered laboratory owners',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  fontSize: isVerySmall ? 14 : 16,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Total Laboratory Owners: ${labs.length}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              if (labs.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: const ValueKey('lab_owners_search'),
                        initialValue: _labOwnersSearchQuery,
                        onChanged: (value) {
                          _searchDebounceTimer?.cancel();
                          _searchDebounceTimer = Timer(
                            const Duration(milliseconds: 500),
                            () {
                              setState(() {
                                _labOwnersSearchQuery = value;
                              });
                            },
                          );
                        },
                        decoration: InputDecoration(
                          hintText:
                              'Search lab owners by name, lab, email, phone, or status...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                    ),
                    if (_labOwnersSearchQuery.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          'Found: ${_filterLabOwners(labs).length}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              if (labs.isNotEmpty) const SizedBox(height: 24),
              if (labs.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No laboratory owners found',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                if (_filterLabOwners(labs).isEmpty)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No lab owners match your search',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                else
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filterLabOwners(labs).length,
                        itemBuilder: (context, index) {
                          final filteredLabs = _filterLabOwners(labs);
                          final owner = filteredLabs[index];
                          final name = owner['name'];
                          final displayName = name is Map
                              ? '${name['first'] ?? ''} ${name['last'] ?? ''}'
                                    .trim()
                              : (name?.toString() ?? 'Unknown');
                          final initial = displayName.isNotEmpty
                              ? displayName.substring(0, 1).toUpperCase()
                              : 'L';

                          // Format address
                          final address = owner['address'];
                          final addressStr = address is Map
                              ? '${address['street'] ?? ''}, ${address['city'] ?? ''}, ${address['state'] ?? ''} ${address['postal_code'] ?? ''}'
                                    .trim()
                                    .replaceAll(RegExp(r',\s*,'), ',')
                                    .replaceAll(RegExp(r'^,\s*'), '')
                                    .replaceAll(RegExp(r',\s*$'), '')
                              : 'N/A';

                          // Format dates
                          final subscriptionStart =
                              owner['date_subscription'] != null
                              ? _formatFullDate(owner['date_subscription'])
                              : 'N/A';
                          final subscriptionEnd =
                              owner['subscription_end'] != null
                              ? _formatFullDate(owner['subscription_end'])
                              : 'N/A';

                          return AnimatedCard(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: owner['status'] == 'approved'
                                    ? AppTheme.successGreen
                                    : owner['status'] == 'pending'
                                    ? AppTheme.accentOrange
                                    : AppTheme.errorRed,
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(owner['lab_name'] ?? 'Lab'),
                              trailing: Chip(
                                label: Text(
                                  owner['status'] ?? 'unknown',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: owner['status'] == 'approved'
                                    ? AppTheme.successGreen
                                    : owner['status'] == 'pending'
                                    ? AppTheme.accentOrange
                                    : AppTheme.errorRed,
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildDetailRow(
                                        Icons.person,
                                        'Lab Owner',
                                        displayName,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.science,
                                        'Lab Name',
                                        owner['lab_name'] ?? 'N/A',
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.email,
                                        'Email',
                                        owner['email'] ?? 'N/A',
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.phone,
                                        'Phone',
                                        owner['phone_number'] ?? 'N/A',
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.location_on,
                                        'Address',
                                        addressStr,
                                      ),
                                      const Divider(height: 24),
                                      _buildDetailRow(
                                        Icons.calendar_today,
                                        'Subscription Start',
                                        subscriptionStart,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.event,
                                        'Subscription End',
                                        subscriptionEnd,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.check_circle,
                                        'Active Status',
                                        owner['is_active'] == true
                                            ? 'Active'
                                            : 'Inactive',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showPendingRequestsDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await ApiService.get(ApiConfig.adminLabOwners);

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

      if (!mounted) return;

      // Filter only pending requests
      final allLabs = response is List ? response : [];
      final pendingRequests = allLabs
          .where((owner) => owner['status'] == 'pending')
          .toList();

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.pending_actions, color: AppTheme.accentOrange),
              const SizedBox(width: 12),
              const Text('Pending Approval Requests'),
              const Spacer(),
              Chip(
                label: Text(
                  '${pendingRequests.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: AppTheme.accentOrange,
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.7,
            child: pendingRequests.isNotEmpty
                ? ListView.builder(
                    itemCount: pendingRequests.length,
                    itemBuilder: (context, index) {
                      final owner = pendingRequests[index];
                      final name = owner['name'];
                      final displayName = name is Map
                          ? '${name['first'] ?? ''} ${name['last'] ?? ''}'
                                .trim()
                          : (name?.toString() ?? 'Unknown');
                      final initial = displayName.isNotEmpty
                          ? displayName.substring(0, 1).toUpperCase()
                          : 'L';

                      // Format address
                      final address = owner['address'];
                      final addressStr = address is Map
                          ? '${address['street'] ?? ''}, ${address['city'] ?? ''}, ${address['state'] ?? ''} ${address['postal_code'] ?? ''}'
                                .trim()
                                .replaceAll(RegExp(r',\s*,'), ',')
                                .replaceAll(RegExp(r'^,\s*'), '')
                                .replaceAll(RegExp(r',\s*$'), '')
                          : 'N/A';

                      // Format dates
                      final requestDate = owner['date_subscription'] != null
                          ? _formatFullDate(owner['date_subscription'])
                          : 'N/A';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.accentOrange,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(owner['lab_name'] ?? 'Lab'),
                          trailing: const Chip(
                            label: Text(
                              'PENDING',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: AppTheme.accentOrange,
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow(
                                    Icons.person,
                                    'Lab Owner',
                                    displayName,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.science,
                                    'Lab Name',
                                    owner['lab_name'] ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.email,
                                    'Email',
                                    owner['email'] ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.phone,
                                    'Phone',
                                    owner['phone_number'] ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.location_on,
                                    'Address',
                                    addressStr,
                                  ),
                                  const Divider(height: 24),
                                  _buildDetailRow(
                                    Icons.calendar_today,
                                    'Request Date',
                                    requestDate,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          Navigator.pop(dialogContext);
                                          await _approveLabOwner(
                                            owner['_id'],
                                            displayName,
                                          );
                                        },
                                        icon: const Icon(Icons.check),
                                        label: const Text('Approve'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.successGreen,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
                                        onPressed: () async {
                                          Navigator.pop(dialogContext);
                                          await _rejectLabOwner(
                                            owner['_id'],
                                            displayName,
                                          );
                                        },
                                        icon: const Icon(Icons.close),
                                        label: const Text('Reject'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.errorRed,
                                          side: const BorderSide(
                                            color: AppTheme.errorRed,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: AppTheme.successGreen,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No pending approval requests',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Close loading dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading pending requests: $e')),
          );
        }
      }
    }
  }

  void _showLabOwnersDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await ApiService.get(ApiConfig.adminLabOwners);

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Laboratory Owners'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.7,
            child: response is List && response.isNotEmpty
                ? ListView.builder(
                    itemCount: response.length,
                    itemBuilder: (context, index) {
                      final owner = response[index];
                      final name = owner['name'];
                      final displayName = name is Map
                          ? '${name['first'] ?? ''} ${name['last'] ?? ''}'
                                .trim()
                          : (name?.toString() ?? 'Unknown');
                      final initial = displayName.isNotEmpty
                          ? displayName.substring(0, 1).toUpperCase()
                          : 'L';

                      // Format address
                      final address = owner['address'];
                      final addressStr = address is Map
                          ? '${address['street'] ?? ''}, ${address['city'] ?? ''}, ${address['state'] ?? ''} ${address['postal_code'] ?? ''}'
                                .trim()
                                .replaceAll(RegExp(r',\s*,'), ',')
                                .replaceAll(RegExp(r'^,\s*'), '')
                                .replaceAll(RegExp(r',\s*$'), '')
                          : 'N/A';

                      // Format dates
                      final subscriptionStart =
                          owner['date_subscription'] != null
                          ? _formatFullDate(owner['date_subscription'])
                          : 'N/A';
                      final subscriptionEnd = owner['subscription_end'] != null
                          ? _formatFullDate(owner['subscription_end'])
                          : 'N/A';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: owner['status'] == 'approved'
                                ? AppTheme.successGreen
                                : owner['status'] == 'pending'
                                ? AppTheme.accentOrange
                                : AppTheme.errorRed,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(owner['lab_name'] ?? 'Lab'),
                          trailing: Chip(
                            label: Text(
                              owner['status'] ?? 'unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: owner['status'] == 'approved'
                                ? AppTheme.successGreen
                                : owner['status'] == 'pending'
                                ? AppTheme.accentOrange
                                : AppTheme.errorRed,
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow(
                                    Icons.person,
                                    'Lab Owner',
                                    displayName,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.science,
                                    'Lab Name',
                                    owner['lab_name'] ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.email,
                                    'Email',
                                    owner['email'] ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.phone,
                                    'Phone',
                                    owner['phone_number'] ?? 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.location_on,
                                    'Address',
                                    addressStr,
                                  ),
                                  const Divider(height: 24),
                                  _buildDetailRow(
                                    Icons.calendar_today,
                                    'Subscription Start',
                                    subscriptionStart,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.event,
                                    'Subscription End',
                                    subscriptionEnd,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.check_circle,
                                    'Active Status',
                                    owner['is_active'] == true
                                        ? 'Active'
                                        : 'Inactive',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No laboratory owners found'),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Close loading dialog
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error loading owners: $e')));
        }
      }
    }
  }

  void _showSubscriptionsDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await ApiService.get(
        ApiConfig.adminExpiringSubscriptions,
      );

      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

      if (!mounted) return;

      final labs = response['labs'] as List? ?? [];
      final count = response['count'] ?? 0;

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.accentOrange,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Expiring Subscriptions',
                  style: TextStyle(fontSize: 20),
                ),
              ),
              Chip(
                label: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: AppTheme.accentOrange,
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.7,
            child: labs.isNotEmpty
                ? ListView.builder(
                    itemCount: labs.length,
                    itemBuilder: (context, index) {
                      final lab = labs[index];
                      final name = lab['name'];
                      final displayName = name is Map
                          ? '${name['first'] ?? ''} ${name['last'] ?? ''}'
                                .trim()
                          : (name?.toString() ?? 'Unknown Lab');
                      final initial = displayName.isNotEmpty
                          ? displayName.substring(0, 1).toUpperCase()
                          : 'L';

                      final labName = lab['lab_name'] ?? 'N/A';
                      final email = lab['email'] ?? 'N/A';
                      final phone = lab['phone_number'] ?? 'N/A';

                      final subscriptionEnd = lab['subscription_end'] != null
                          ? _formatFullDate(lab['subscription_end'])
                          : 'N/A';

                      // Calculate days remaining
                      int daysRemaining = 0;
                      if (lab['subscription_end'] != null) {
                        try {
                          final endDate = DateTime.parse(
                            lab['subscription_end'].toString(),
                          );
                          daysRemaining = endDate
                              .difference(DateTime.now())
                              .inDays;
                        } catch (e) {
                          daysRemaining = 0;
                        }
                      }

                      final isUrgent = daysRemaining <= 7;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        color: isUrgent
                            ? AppTheme.errorRed.withValues(alpha: 0.05)
                            : null,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: isUrgent
                                ? AppTheme.errorRed
                                : AppTheme.accentOrange,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(labName),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isUrgent
                                  ? AppTheme.errorRed
                                  : AppTheme.accentOrange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isUrgent ? Icons.error : Icons.access_time,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  daysRemaining > 0
                                      ? '$daysRemaining days'
                                      : 'Expired',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow(
                                    Icons.person,
                                    'Lab Owner',
                                    displayName,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    Icons.science,
                                    'Lab Name',
                                    labName,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(Icons.email, 'Email', email),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(Icons.phone, 'Phone', phone),
                                  const Divider(height: 24),
                                  _buildDetailRow(
                                    Icons.event,
                                    'Subscription End Date',
                                    subscriptionEnd,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildDetailRow(
                                    isUrgent ? Icons.error : Icons.access_time,
                                    'Days Remaining',
                                    daysRemaining > 0
                                        ? '$daysRemaining days'
                                        : 'Expired',
                                  ),
                                  if (isUrgent) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorRed.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppTheme.errorRed.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.warning,
                                            color: AppTheme.errorRed,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              daysRemaining > 0
                                                  ? 'Urgent: Subscription expires in $daysRemaining days!'
                                                  : 'Critical: Subscription has expired!',
                                              style: const TextStyle(
                                                color: AppTheme.errorRed,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          // TODO: Implement renew functionality
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Renew subscription for $displayName coming soon',
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Renew'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.successGreen,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          _showContactDialog(
                                            context,
                                            lab['_id'],
                                            displayName,
                                            email,
                                          );
                                        },
                                        icon: const Icon(Icons.email),
                                        label: const Text('Contact'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.primaryBlue,
                                          side: const BorderSide(
                                            color: AppTheme.primaryBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: AppTheme.successGreen,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No expiring subscriptions',
                          style: TextStyle(fontSize: 18),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'All subscriptions are current',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Close loading dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading subscriptions: $e')),
          );
        }
      }
    }
  }

  Widget _buildNotificationsSection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    return FutureBuilder(
      future: ApiService.get(ApiConfig.adminNotifications),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(50),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        final response = snapshot.data as Map<String, dynamic>?;
        final notifications = response?['notifications'] as List? ?? [];
        final unreadCount = response?['unreadCount'] ?? 0;
        final total = response?['total'] ?? 0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 80,
            vertical: isVerySmall ? 40 : (isMobile ? 60 : 80),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isVerySmall ? 24 : (isMobile ? 28 : 36),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'View and manage system notifications and messages',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  fontSize: isVerySmall ? 14 : 16,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Total Notifications: $total',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.circle,
                            color: Colors.white,
                            size: 8,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$unreadCount Unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              if (notifications.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No notifications',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        final isRead = notification['is_read'] ?? false;
                        final type = notification['type'] ?? 'system';
                        final title = notification['title'] ?? 'Notification';
                        final message = notification['message'] ?? '';
                        final createdAt = notification['createdAt'];
                        final from = notification['from']; // Lab owner info

                        IconData icon;
                        Color iconColor;
                        switch (type) {
                          case 'alert':
                            icon = Icons.warning;
                            iconColor = AppTheme.errorRed;
                            break;
                          case 'system':
                            icon = Icons.info;
                            iconColor = AppTheme.primaryBlue;
                            break;
                          case 'subscription':
                            icon = Icons.payment;
                            iconColor = AppTheme.accentOrange;
                            break;
                          case 'message':
                            icon = Icons.mail;
                            iconColor = AppTheme.secondaryTeal;
                            break;
                          default:
                            icon = Icons.notifications;
                            iconColor = AppTheme.secondaryTeal;
                        }

                        return AnimatedCard(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isRead
                                  ? null
                                  : AppTheme.primaryBlue.withValues(
                                      alpha: 0.03,
                                    ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                ExpansionTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: iconColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      icon,
                                      color: iconColor,
                                      size: 24,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontWeight: isRead
                                                ? FontWeight.w500
                                                : FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      if (from != null) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.secondaryTeal
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.person,
                                                size: 12,
                                                color: AppTheme.secondaryTeal,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                from['name']?.toString() ??
                                                    'Lab Owner',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppTheme.secondaryTeal,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        message.length > 100
                                            ? '${message.substring(0, 100)}...'
                                            : message,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            _formatNotificationDate(createdAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          if (from != null) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryBlue
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.reply,
                                                    size: 8,
                                                    color: AppTheme.primaryBlue,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    'Reply',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color:
                                                          AppTheme.primaryBlue,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (from != null) ...[
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            onPressed: () {
                                              _showReplyDialog(
                                                context,
                                                notification['_id'].toString(),
                                                from['email']?.toString() ?? '',
                                                from['name']?.toString() ??
                                                    'Lab Owner',
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.reply,
                                              size: 16,
                                            ),
                                            color: AppTheme.primaryBlue,
                                            tooltip: 'Reply',
                                          ),
                                        ),
                                      ],
                                      isRead
                                          ? const Icon(
                                              Icons.mark_email_read,
                                              color: Colors.grey,
                                              size: 16,
                                            )
                                          : Container(
                                              width: 16,
                                              height: 16,
                                              decoration: const BoxDecoration(
                                                color: AppTheme.errorRed,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.fiber_manual_record,
                                                color: Colors.white,
                                                size: 8,
                                              ),
                                            ),
                                    ],
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (from != null) ...[
                                            _buildDetailRow(
                                              Icons.person,
                                              'From',
                                              from['name']?.toString() ??
                                                  'System',
                                            ),
                                            const SizedBox(height: 8),
                                            if (from['email'] != null)
                                              _buildDetailRow(
                                                Icons.email,
                                                'Email',
                                                from['email'].toString(),
                                              ),
                                            const Divider(height: 24),
                                          ],
                                          const Text(
                                            'Message:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          SelectableText(
                                            message,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              if (!isRead)
                                                ElevatedButton.icon(
                                                  onPressed: () async {
                                                    try {
                                                      await ApiService.put(
                                                        '${ApiConfig.adminNotifications}/${notification['_id']}/read',
                                                        {},
                                                      );
                                                      setState(() {});
                                                      _loadDashboardData();
                                                    } catch (e) {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Error: $e',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  icon: const Icon(
                                                    Icons.mark_email_read,
                                                  ),
                                                  label: const Text(
                                                    'Mark as Read',
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            AppTheme
                                                                .successGreen,
                                                        foregroundColor:
                                                            Colors.white,
                                                      ),
                                                ),
                                              if (!isRead && from != null)
                                                const SizedBox(width: 12),
                                              if (from != null)
                                                OutlinedButton.icon(
                                                  onPressed: () {
                                                    _showReplyDialog(
                                                      context,
                                                      notification['_id']
                                                          .toString(),
                                                      from['email']
                                                              ?.toString() ??
                                                          '',
                                                      from['name']
                                                              ?.toString() ??
                                                          'Lab Owner',
                                                    );
                                                  },
                                                  icon: const Icon(Icons.reply),
                                                  label: const Text('Reply'),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                        foregroundColor:
                                                            AppTheme
                                                                .primaryBlue,
                                                        side: const BorderSide(
                                                          color: AppTheme
                                                              .primaryBlue,
                                                        ),
                                                      ),
                                                ),
                                            ],
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
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showReplyDialog(
    BuildContext context,
    String notificationId,
    String toEmail,
    String toName,
  ) {
    final TextEditingController replyController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.reply, color: AppTheme.primaryBlue),
            const SizedBox(width: 12),
            Expanded(child: Text('Reply to $toName')),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To: $toEmail',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: replyController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Type your reply here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              replyController.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (replyController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a message')),
                );
                return;
              }

              try {
                // Send notification reply to the lab owner
                await ApiService.sendNotificationToOwner(
                  ownerId:
                      notificationId, // This should be the owner ID from the notification
                  title: 'Admin Reply',
                  message: replyController.text.trim(),
                  type: 'message',
                );

                Navigator.pop(dialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Reply sent to $toName'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error sending reply: $e')),
                  );
                }
              } finally {
                replyController.dispose();
              }
            },
            icon: const Icon(Icons.send),
            label: const Text('Send Reply'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _formatNotificationDate(dynamic date) {
    if (date == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(date.toString());
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
      }
    } catch (e) {
      return date.toString();
    }
  }

  Future<void> _approveLabOwner(String ownerId, String displayName) async {
    try {
      final result = await ApiService.approveLabOwner(ownerId);

      if (result['success'] == true || result['message'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Successfully approved $displayName'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        // Refresh the pending approvals section
        setState(() {});
      } else {
        throw Exception(result['message'] ?? 'Approval failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to approve $displayName: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _rejectLabOwner(String ownerId, String displayName) async {
    final TextEditingController reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: AppTheme.errorRed),
            const SizedBox(width: 12),
            Text('Reject $displayName'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'Enter reason for rejection...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pop(reasonController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final apiResult = await ApiService.rejectLabOwner(
          ownerId,
          rejectionReason: result,
        );

        if (apiResult['success'] == true || apiResult['message'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Successfully rejected $displayName'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
          // Refresh the pending approvals section
          setState(() {});
        } else {
          throw Exception(apiResult['message'] ?? 'Rejection failed');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to reject $displayName: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Widget _buildFeedbackSection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    return FutureBuilder(
      future: ApiService.get(ApiConfig.adminFeedback),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(50),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(50),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        final response = snapshot.data as Map<String, dynamic>?;
        final feedbackList = response?['feedback'] as List? ?? [];
        final total = response?['total'] ?? 0;
        final pendingCount = response?['pendingCount'] ?? 0;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 80,
            vertical: isVerySmall ? 40 : (isMobile ? 60 : 80),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Feedback',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isVerySmall ? 24 : (isMobile ? 28 : 36),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'View and manage feedback from patients, staff, and doctors',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                  fontSize: isVerySmall ? 14 : 16,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    'Total Feedback: $total',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.pending,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$pendingCount Pending',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              if (feedbackList.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.feedback_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No feedback yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: feedbackList.length,
                      itemBuilder: (context, index) {
                        final feedback = feedbackList[index];
                        final userId = feedback['user_id'];
                        final userRole = feedback['user_role'] ?? 'User';
                        final userName = userId != null
                            ? '${userId['full_name']?['first'] ?? ''} ${userId['full_name']?['last'] ?? ''}'
                                  .trim()
                            : 'Anonymous';
                        final userEmail = userId?['email'] ?? 'N/A';
                        final rating = feedback['rating'] ?? 0;
                        final message = feedback['message'] ?? '';
                        final targetType = feedback['target_type'] ?? 'system';
                        final status = feedback['status'] ?? 'pending';
                        final createdAt = feedback['createdAt'];
                        final isAnonymous = feedback['is_anonymous'] ?? false;

                        // Format role for display
                        String displayRole = userRole;
                        if (userRole == 'Owner') displayRole = 'Lab Owner';

                        // Format user display name with role
                        final userDisplayName = isAnonymous
                            ? 'Anonymous User'
                            : '$userName ($displayRole)';

                        Color statusColor;
                        switch (status) {
                          case 'reviewed':
                            statusColor = AppTheme.primaryBlue;
                            break;
                          case 'responded':
                            statusColor = AppTheme.successGreen;
                            break;
                          default:
                            statusColor = AppTheme.accentOrange;
                        }

                        return AnimatedCard(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: statusColor,
                              child: Text(
                                isAnonymous
                                    ? '?'
                                    : userName.isNotEmpty
                                    ? userName.substring(0, 1).toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    userDisplayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Row(
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      i < rating
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              '${targetType.toUpperCase()} • ${_formatNotificationDate(createdAt)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            trailing: Chip(
                              label: Text(
                                status.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor: statusColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isAnonymous) ...[
                                      _buildDetailRow(
                                        Icons.person,
                                        'Name',
                                        userName,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.badge,
                                        'Role',
                                        displayRole,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildDetailRow(
                                        Icons.email,
                                        'Email',
                                        userEmail,
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    _buildDetailRow(
                                      Icons.category,
                                      'Target Type',
                                      targetType,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDetailRow(
                                      Icons.calendar_today,
                                      'Submitted',
                                      _formatFullDate(createdAt),
                                    ),
                                    const Divider(height: 24),
                                    Text(
                                      'Feedback Message:',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      message,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showContactDialog(
    BuildContext context,
    String ownerId,
    String ownerName,
    String ownerEmail,
  ) {
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.mail, color: AppTheme.primaryBlue),
            const SizedBox(width: 12),
            Expanded(child: Text('Contact $ownerName')),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To: $ownerEmail',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subjectController,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'Enter subject...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: messageController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Type your message here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              subjectController.dispose();
              messageController.dispose();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (subjectController.text.trim().isEmpty ||
                  messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter both subject and message'),
                  ),
                );
                return;
              }

              try {
                await ApiService.sendNotificationToOwner(
                  ownerId: ownerId,
                  title: subjectController.text.trim(),
                  message: messageController.text.trim(),
                  type: 'message',
                );

                Navigator.pop(dialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ Message sent to $ownerName'),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error sending message: $e'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              } finally {
                subjectController.dispose();
                messageController.dispose();
              }
            },
            icon: const Icon(Icons.send),
            label: const Text('Send Message'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
