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
import '../../widgets/system_health_widget.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _statsData;
  Map<String, dynamic>? _systemHealth;
  Map<String, dynamic>? _realtimeMetrics;
  Map<String, dynamic>? _alertsData;
  bool _isLoading = true;
  Timer? _refreshTimer;
  int _selectedIndex = 0;

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
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      ApiService.setAuthToken(authProvider.token);

      final results = await Future.wait([
        ApiService.get(ApiConfig.adminDashboard),
        ApiService.get(ApiConfig.adminStats),
        ApiService.get(ApiConfig.adminSystemHealth),
        ApiService.get(ApiConfig.adminRealtimeMetrics),
        ApiService.get(ApiConfig.adminAlerts),
      ]);

      setState(() {
        _dashboardData = results[0] is Map<String, dynamic> ? results[0] : {};
        _statsData = results[1] is Map<String, dynamic> ? results[1] : {};
        _systemHealth = results[2] is Map<String, dynamic> ? results[2] : {};
        _realtimeMetrics = results[3] is Map<String, dynamic> ? results[3] : {};
        _alertsData = results[4] is Map<String, dynamic> ? results[4] : {};
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
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 500;

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
          : null,
      drawer: isMobile
          ? AdminSidebar(
              selectedIndex: _selectedIndex,
              onItemSelected: (index) {
                setState(() => _selectedIndex = index);
                Navigator.pop(context);
                _handleNavigation(index);
              },
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            AdminSidebar(
              selectedIndex: _selectedIndex,
              onItemSelected: _handleNavigation,
            ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Hero Section
                  AppAnimations.blurFadeIn(
                    _buildHeroSection(context, isMobile, isVerySmall),
                  ),
                  // System Health Section
                  if (_selectedIndex == 0 || _selectedIndex == 2)
                    AppAnimations.elasticSlideIn(
                      _buildSystemHealthSection(context, isMobile, isVerySmall),
                      delay: 200.ms,
                    ),
                  // Stats Section
                  if (_selectedIndex == 0 || _selectedIndex == 1)
                    AppAnimations.elasticSlideIn(
                      _buildStatsSection(context, isMobile, isVerySmall),
                      delay: 300.ms,
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
                      _buildQuickActionsSection(context, isMobile, isVerySmall),
                      delay: 700.ms,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 48,
        vertical: isVerySmall ? 48 : (isMobile ? 80 : 120),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAnimations.liquidMorph(
            Row(
              children: [
                AppAnimations.rotateIn(
                  Icon(
                    Icons.admin_panel_settings,
                    size: isVerySmall ? 48 : (isMobile ? 56 : 72),
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
                        'Welcome to Admin Dashboard',
                        Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: Colors.white,
                              fontSize: isVerySmall ? 28 : (isMobile ? 36 : 48),
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
                                    ? 14
                                    : (isMobile ? 18 : 22),
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
                    'Active Labs',
                    '${_statsData?['stats']?['activeLabs'] ?? 0}',
                    Icons.science,
                    AppTheme.primaryBlue,
                    isMobile,
                  ),
                  glowColor: AppTheme.primaryBlue,
                ),
                AppAnimations.glowPulse(
                  _buildEnhancedHeroMetric(
                    'Total Revenue',
                    '\$${_statsData?['stats']?['totalRevenue'] ?? '0.00'}',
                    Icons.attach_money,
                    AppTheme.successGreen,
                    isMobile,
                  ),
                  glowColor: AppTheme.successGreen,
                ),
                AppAnimations.glowPulse(
                  _buildEnhancedHeroMetric(
                    'Active Subscriptions',
                    '${_statsData?['stats']?['activeSubscriptions'] ?? 0}',
                    Icons.payment,
                    AppTheme.secondaryTeal,
                    isMobile,
                  ),
                  glowColor: AppTheme.secondaryTeal,
                ),
              ],
            ),
            delay: 600.ms,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemHealthSection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isVerySmall ? 40 : (isMobile ? 60 : 100),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              'System Monitoring',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isVerySmall ? 20 : (isMobile ? 28 : 36),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isVerySmall ? 40 : 60),
          SystemHealthWidget(
            systemHealth: _systemHealth,
            realtimeMetrics: _realtimeMetrics,
            alertsData: _alertsData,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    bool isMobile,
    bool isVerySmall,
  ) {
    final statsInfo = _statsData?['stats'];

    final stats = [
      {
        'title': 'Active Laboratories',
        'value': '${statsInfo?['activeLabs'] ?? 0}',
        'change': '+${_dashboardData?['totalLabs'] ?? 0} total',
        'icon': Icons.science,
        'color': AppTheme.primaryBlue,
        'description': 'Currently active lab accounts',
      },
      {
        'title': 'Total Revenue',
        'value': '\$${statsInfo?['totalRevenue'] ?? '0.00'}',
        'change': 'All Time',
        'icon': Icons.attach_money,
        'color': AppTheme.successGreen,
        'description': 'Sum of subscription fees from all active lab owners',
      },
      {
        'title': 'Active Subscriptions',
        'value': '${statsInfo?['activeSubscriptions'] ?? 0}',
        'change': '${_dashboardData?['expiringLabsCount'] ?? 0} expiring',
        'icon': Icons.payment,
        'color': AppTheme.secondaryTeal,
        'description': 'Labs with active subscriptions',
      },
      {
        'title': 'Pending Requests',
        'value': '${_dashboardData?['pendingRequests'] ?? 0}',
        'change': 'Needs Review',
        'icon': Icons.pending_actions,
        'color': AppTheme.accentOrange,
        'description': 'Lab owner applications pending',
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 80,
        vertical: isVerySmall ? 40 : (isMobile ? 60 : 100),
      ),
      child: Column(
        children: [
          AppAnimations.fadeIn(
            Text(
              isVerySmall ? 'System Overview' : 'System Overview & Statistics',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: isVerySmall ? 20 : (isMobile ? 28 : 36),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: isVerySmall ? 40 : 60),
          AnimatedGridView(
            crossAxisCount: isMobile ? 1 : 2,
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            padding: EdgeInsets.zero,
            children: stats.map((stat) {
              return AnimatedCard(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: (stat['color'] as Color).withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              stat['icon'] as IconData,
                              color: stat['color'] as Color,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stat['title'] as String,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    stat['change'] as String,
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        stat['value'] as String,
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: stat['color'] as Color,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        stat['description'] as String,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
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
        'onTap': () => _showLabOwnersDialog(context),
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
          const SnackBar(content: Text('Reports feature coming soon!')),
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
            crossAxisCount: isMobile ? 1 : 2,
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            padding: EdgeInsets.zero,
            children: actions.map((action) {
              return AnimatedCard(
                onTap: action['onTap'] as VoidCallback,
                child: Padding(
                  padding: const EdgeInsets.all(24),
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
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        action['title'] as String,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action['subtitle'] as String,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Access Now',
                            style: TextStyle(
                              color: action['color'] as Color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            color: action['color'] as Color,
                            size: 16,
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
  ) {
    return Container(
      width: isMobile ? double.infinity : 240,
      padding: const EdgeInsets.all(24),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
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
                ),
                const SizedBox(height: 4),
                Text(
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

  void _showLabOwnersDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await ApiService.get(ApiConfig.adminLabOwners);

      if (!context.mounted) return;

      Navigator.of(context).pop(); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Laboratory Owners'),
          content: SizedBox(
            width: 600,
            height: 400,
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
                      return ListTile(
                        leading: CircleAvatar(child: Text(initial)),
                        title: Text(displayName),
                        subtitle: Text(
                          'Status: ${owner['status']} | Active: ${owner['is_active']}',
                        ),
                        trailing: Chip(
                          label: Text(owner['status'] ?? 'unknown'),
                          backgroundColor: owner['status'] == 'approved'
                              ? AppTheme.successGreen
                              : owner['status'] == 'pending'
                              ? AppTheme.accentOrange
                              : AppTheme.errorRed,
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading owners: $e')));
      }
    }
  }

  void _showSubscriptionsDialog(BuildContext context) async {
    try {
      final response = await ApiService.get(
        ApiConfig.adminExpiringSubscriptions,
      );
      if (!context.mounted) return;

      final labs = response['labs'] as List? ?? [];

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Expiring Subscriptions (${response['count'] ?? 0})'),
          content: SizedBox(
            width: 600,
            height: 400,
            child: labs.isNotEmpty
                ? ListView.builder(
                    itemCount: labs.length,
                    itemBuilder: (context, index) {
                      final lab = labs[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.warning,
                          color: AppTheme.accentOrange,
                        ),
                        title: Text(lab['name'] ?? 'Unknown Lab'),
                        subtitle: Text('Expires: ${lab['subscription_end']}'),
                      );
                    },
                  )
                : const Center(child: Text('No expiring subscriptions')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading subscriptions: $e')),
        );
      }
    }
  }
}
