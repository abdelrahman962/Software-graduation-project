import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
import '../../widgets/admin_sidebar.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;
  String _selectedReportType = 'comprehensive';
  String _selectedPeriod = 'monthly';
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isSidebarOpen = true;
  int _selectedIndex = 2; // Reports index in sidebar

  final List<Map<String, dynamic>> _reportTypes = [
    {
      'value': 'comprehensive',
      'label': 'Comprehensive Report',
      'icon': Icons.analytics,
      'description': 'Complete platform overview with all metrics',
    },
    {
      'value': 'revenue',
      'label': 'Revenue Report',
      'icon': Icons.attach_money,
      'description': 'Subscription revenue and financial projections',
    },
    {
      'value': 'labs',
      'label': 'Labs Report',
      'icon': Icons.science,
      'description': 'Laboratory accounts and subscription status',
    },
    {
      'value': 'subscriptions',
      'label': 'Subscriptions Report',
      'icon': Icons.payment,
      'description': 'Subscription renewals and revenue forecast',
    },
    {
      'value': 'platform',
      'label': 'Platform Growth',
      'icon': Icons.trending_up,
      'description': 'Platform growth, registrations, and retention',
    },
  ];

  final List<Map<String, String>> _periods = [
    {'value': 'daily', 'label': 'Today'},
    {'value': 'weekly', 'label': 'Last 7 Days'},
    {'value': 'monthly', 'label': 'This Month'},
    {'value': 'yearly', 'label': 'This Year'},
    {'value': 'custom', 'label': 'Custom Range'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        ApiService.setAuthToken(authProvider.token);
        _loadReport();
      }
    });
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      ApiService.setAuthToken(authProvider.token);

      Map<String, String> params = {
        'type': _selectedReportType,
        'period': _selectedPeriod,
      };

      if (_selectedPeriod == 'custom' &&
          _customStartDate != null &&
          _customEndDate != null) {
        params['startDate'] = _customStartDate!.toIso8601String();
        params['endDate'] = _customEndDate!.toIso8601String();
      }

      final response = await ApiService.get('/admin/reports', params: params);

      if (mounted) {
        setState(() {
          _reportData = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleSidebar() {
    if (mounted) {
      setState(() => _isSidebarOpen = !_isSidebarOpen);
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;

    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: isMobile
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : IconButton(
                icon: AnimatedIcon(
                  icon: AnimatedIcons.menu_close,
                  progress: _isSidebarOpen
                      ? const AlwaysStoppedAnimation(1.0)
                      : const AlwaysStoppedAnimation(0.0),
                ),
                onPressed: _toggleSidebar,
              ),
        title: Text(
          'System Reports',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      drawer: isMobile
          ? Drawer(
              child: AdminSidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: (index) {
                  setState(() => _selectedIndex = index);
                  Navigator.pop(context);
                },
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile && _isSidebarOpen)
            SizedBox(
              width: 250,
              child: AdminSidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: (index) {
                  setState(() => _selectedIndex = index);
                },
              ),
            ),
          Expanded(child: _buildReportsContent(context, isMobile)),
        ],
      ),
    );
  }

  Widget _buildReportsContent(BuildContext context, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportControls(context, isMobile),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_reportData != null)
            _buildReportDisplay(context, isMobile)
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select report type and period to generate report',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportControls(BuildContext context, bool isMobile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report Configuration',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (isMobile) ...[
              _buildReportTypeDropdown(),
              const SizedBox(height: 16),
              _buildPeriodDropdown(),
              if (_selectedPeriod == 'custom') ...[
                const SizedBox(height: 16),
                _buildCustomDateButton(),
              ],
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: _buildGenerateButton()),
            ] else
              Row(
                children: [
                  Expanded(flex: 2, child: _buildReportTypeDropdown()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildPeriodDropdown()),
                  if (_selectedPeriod == 'custom') ...[
                    const SizedBox(width: 16),
                    Expanded(child: _buildCustomDateButton()),
                  ],
                  const SizedBox(width: 16),
                  _buildGenerateButton(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportTypeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedReportType,
      decoration: const InputDecoration(
        labelText: 'Report Type',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.analytics),
      ),
      isExpanded: true,
      items: _reportTypes.map((type) {
        return DropdownMenuItem<String>(
          value: type['value'] as String,
          child: Text(type['label'] as String, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedReportType = value);
        }
      },
    );
  }

  Widget _buildPeriodDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedPeriod,
      decoration: const InputDecoration(
        labelText: 'Time Period',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.calendar_today),
      ),
      isExpanded: true,
      items: _periods.map((period) {
        return DropdownMenuItem<String>(
          value: period['value'],
          child: Text(period['label']!, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedPeriod = value);
          if (value != 'custom') {
            _loadReport();
          }
        }
      },
    );
  }

  Widget _buildCustomDateButton() {
    final dateFormat = DateFormat('MMM dd, yyyy');
    String dateText = 'Select Date Range';
    if (_customStartDate != null && _customEndDate != null) {
      dateText =
          '${dateFormat.format(_customStartDate!)} - ${dateFormat.format(_customEndDate!)}';
    }

    return OutlinedButton.icon(
      onPressed: _selectDateRange,
      icon: const Icon(Icons.date_range),
      label: Text(dateText),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _loadReport,
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
      label: const Text('Generate'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      ),
    );
  }

  Widget _buildReportDisplay(BuildContext context, bool isMobile) {
    final data = _reportData!['data'];
    final period = _reportData!['period'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportHeader(context, period),
        const SizedBox(height: 24),
        if (_selectedReportType == 'comprehensive')
          _buildComprehensiveReport(context, data, isMobile)
        else if (_selectedReportType == 'revenue')
          _buildRevenueReport(context, data, isMobile)
        else if (_selectedReportType == 'labs')
          _buildLabsReport(context, data, isMobile)
        else if (_selectedReportType == 'subscriptions')
          _buildSubscriptionsReport(context, data, isMobile)
        else if (_selectedReportType == 'platform')
          _buildPlatformGrowthReport(context, data, isMobile),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildReportHeader(BuildContext context, Map<String, dynamic> period) {
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');
    final startDate = DateTime.parse(period['start']);
    final endDate = DateTime.parse(period['end']);

    return Card(
      color: AppTheme.primaryBlue.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.primaryBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report Period',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    '${period['days']} days | Generated: ${dateFormat.format(DateTime.parse(_reportData!['generatedAt']))}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComprehensiveReport(
    BuildContext context,
    Map<String, dynamic> data,
    bool isMobile,
  ) {
    final overview = data['systemOverview'];

    return Column(
      children: [
        _buildStatCard('Platform Overview', [
          _buildStatItem(
            'Monthly Revenue',
            '\$${overview['currentMonthlyRevenue']}',
            Icons.attach_money,
            AppTheme.successGreen,
          ),
          _buildStatItem(
            'Projected Yearly',
            '\$${overview['projectedYearlyRevenue']}',
            Icons.trending_up,
            AppTheme.primaryBlue,
          ),
          _buildStatItem(
            'Active Labs',
            '${overview['activeLabs']}',
            Icons.science,
            AppTheme.secondaryTeal,
          ),
          _buildStatItem(
            'Total Labs',
            '${overview['totalLabs']}',
            Icons.business,
            AppTheme.accentOrange,
          ),
        ], isMobile),
        const SizedBox(height: 16),
        _buildRevenueReport(context, data['revenue'], isMobile),
        const SizedBox(height: 16),
        _buildLabsReport(context, data['labs'], isMobile),
        const SizedBox(height: 16),
        _buildSubscriptionsReport(context, data['subscriptions'], isMobile),
      ],
    );
  }

  Widget _buildRevenueReport(
    BuildContext context,
    Map<String, dynamic> data,
    bool isMobile,
  ) {
    final summary = data['summary'];
    final revenueByTier = data['revenueByTier'] as List? ?? [];
    final monthlyTrend = data['monthlyTrend'] as List? ?? [];

    return Column(
      children: [
        _buildStatCard('Revenue Summary', [
          _buildStatItem(
            'Monthly Revenue',
            '\$${summary['currentMonthlyRevenue']}',
            Icons.account_balance,
            AppTheme.successGreen,
          ),
          _buildStatItem(
            'Projected Yearly',
            '\$${summary['projectedYearlyRevenue']}',
            Icons.trending_up,
            AppTheme.primaryBlue,
          ),
          _buildStatItem(
            'New Subscriptions',
            '\$${summary['newSubscriptionRevenue']}',
            Icons.fiber_new,
            AppTheme.secondaryTeal,
          ),
          _buildStatItem(
            'Active Paying Labs',
            '${summary['activePayingLabs']}',
            Icons.payment,
            AppTheme.accentOrange,
          ),
        ], isMobile),
        const SizedBox(height: 16),
        if (revenueByTier.isNotEmpty)
          _buildTableCard(
            'Revenue by Subscription Tier',
            [
              'Subscription Fee',
              'Lab Count',
              'Monthly Revenue',
              'Yearly Revenue',
            ],
            revenueByTier
                .map(
                  (tier) => [
                    '\$${tier['subscriptionFee'] ?? 0}',
                    '${tier['labCount'] ?? 0}',
                    '\$${tier['monthlyRevenue'] ?? '0.00'}',
                    '\$${tier['yearlyRevenue'] ?? '0.00'}',
                  ],
                )
                .cast<List<String>>()
                .toList(),
          ),
        if (monthlyTrend.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildTableCard(
            'Revenue Trend',
            ['Period', 'Revenue', 'New Labs'],
            monthlyTrend
                .map(
                  (month) => [
                    month['period'] ?? 'N/A',
                    '\$${month['revenue'] ?? '0.00'}',
                    '${month['newLabs'] ?? 0}',
                  ],
                )
                .cast<List<String>>()
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildLabsReport(
    BuildContext context,
    Map<String, dynamic> data,
    bool isMobile,
  ) {
    final summary = data['summary'];

    return Column(
      children: [
        _buildStatCard('Labs Summary', [
          _buildStatItem(
            'Total Labs',
            '${summary['totalLabs']}',
            Icons.science,
            AppTheme.primaryBlue,
          ),
          _buildStatItem(
            'Active Labs',
            '${summary['activeLabs']}',
            Icons.check_circle,
            AppTheme.successGreen,
          ),
          _buildStatItem(
            'Inactive Labs',
            '${summary['inactiveLabs']}',
            Icons.cancel,
            AppTheme.errorRed,
          ),
          _buildStatItem(
            'New Labs',
            '${summary['newLabsInPeriod']}',
            Icons.fiber_new,
            AppTheme.accentOrange,
          ),
        ], isMobile),
        const SizedBox(height: 16),
        _buildStatCard('Subscription Status', [
          _buildStatItem(
            'Active Subscriptions',
            '${summary['activeSubscriptions']}',
            Icons.verified,
            AppTheme.successGreen,
          ),
          _buildStatItem(
            'Expiring Soon',
            '${summary['expiringSoon']}',
            Icons.warning,
            AppTheme.accentOrange,
          ),
          _buildStatItem(
            'Expired',
            '${summary['expired']}',
            Icons.error,
            AppTheme.errorRed,
          ),
          _buildStatItem(
            'Growth Rate',
            '${summary['growthRate']}',
            Icons.trending_up,
            AppTheme.secondaryTeal,
          ),
        ], isMobile),
      ],
    );
  }

  Widget _buildPlatformGrowthReport(
    BuildContext context,
    Map<String, dynamic> data,
    bool isMobile,
  ) {
    final summary = data['summary'];
    final registrationTrend = data['registrationTrend'] as List? ?? [];

    return Column(
      children: [
        _buildStatCard('Platform Growth', [
          _buildStatItem(
            'Total Applications',
            '${summary['totalApplications']}',
            Icons.app_registration,
            AppTheme.primaryBlue,
          ),
          _buildStatItem(
            'Approved',
            '${summary['approved']}',
            Icons.check_circle,
            AppTheme.successGreen,
          ),
          _buildStatItem(
            'Rejected',
            '${summary['rejected']}',
            Icons.cancel,
            AppTheme.errorRed,
          ),
          _buildStatItem(
            'Pending',
            '${summary['pending']}',
            Icons.pending,
            AppTheme.accentOrange,
          ),
        ], isMobile),
        const SizedBox(height: 16),
        _buildStatCard('Performance Metrics', [
          _buildStatItem(
            'Approval Rate',
            '${summary['approvalRate']}',
            Icons.verified,
            AppTheme.successGreen,
          ),
          _buildStatItem(
            'Retention Rate',
            '${summary['retentionRate']}',
            Icons.people,
            AppTheme.secondaryTeal,
          ),
        ], isMobile),
        if (registrationTrend.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildTableCard(
            'Registration Trend',
            ['Date', 'New Labs'],
            registrationTrend
                .map((day) => [day['date'] ?? 'N/A', '${day['newLabs'] ?? 0}'])
                .cast<List<String>>()
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSubscriptionsReport(
    BuildContext context,
    Map<String, dynamic> data,
    bool isMobile,
  ) {
    final summary = data['summary'];
    final renewals = data['upcomingRenewals'] as List;

    return Column(
      children: [
        _buildStatCard('Subscription Summary', [
          _buildStatItem(
            'Total Subscriptions',
            '${summary['totalSubscriptions']}',
            Icons.payment,
            AppTheme.primaryBlue,
          ),
          _buildStatItem(
            'Active',
            '${summary['activeSubscriptions']}',
            Icons.check_circle,
            AppTheme.successGreen,
          ),
          _buildStatItem(
            'Expired',
            '${summary['expiredSubscriptions']}',
            Icons.cancel,
            AppTheme.errorRed,
          ),
          _buildStatItem(
            'New This Period',
            '${summary['newSubscriptionsInPeriod']}',
            Icons.fiber_new,
            AppTheme.accentOrange,
          ),
        ], isMobile),
        const SizedBox(height: 16),
        _buildStatCard('Renewal Forecast', [
          _buildStatItem(
            'Expiring in 7 Days',
            '${summary['expiringSoon']}',
            Icons.warning,
            AppTheme.accentOrange,
          ),
          _buildStatItem(
            'Expiring in 30 Days',
            '${summary['expiringThisMonth']}',
            Icons.event,
            AppTheme.secondaryTeal,
          ),
          _buildStatItem(
            'Projected Monthly Revenue',
            '\$${summary['projectedMonthlyRevenue']}',
            Icons.trending_up,
            AppTheme.successGreen,
          ),
        ], isMobile),
        const SizedBox(height: 16),
        if (renewals.isNotEmpty)
          _buildTableCard(
            'Upcoming Renewals (Next 30 Days)',
            ['Lab Name', 'Expires', 'Days Left', 'Fee'],
            renewals
                .map(
                  (renewal) => [
                    renewal['labName'] ?? 'N/A',
                    DateFormat(
                      'MMM dd, yyyy',
                    ).format(DateTime.parse(renewal['expiryDate'])),
                    '${renewal['daysRemaining']} days',
                    '\$${(renewal['subscriptionFee'] ?? 0).toStringAsFixed(2)}',
                  ],
                )
                .cast<List<String>>()
                .toList(),
          ),
      ],
    );
  }

  Widget _buildStatCard(String title, List<Widget> stats, bool isMobile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isMobile ? 2 : 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isMobile ? 1.5 : 2,
              children: stats,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(
    String title,
    List<String> headers,
    List<List<String>> rows,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(
                  AppTheme.primaryBlue.withOpacity(0.1),
                ),
                columns: headers
                    .map(
                      (header) => DataColumn(
                        label: Text(
                          header,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                    .toList(),
                rows: rows
                    .map(
                      (row) => DataRow(
                        cells: row.map((cell) => DataCell(Text(cell))).toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
