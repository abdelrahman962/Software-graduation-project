import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';
// import '../../widgets/admin_sidebar.dart';
// import 'package:flutter_animate/flutter_animate.dart';

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
  final int _selectedIndex = 6; // System Reports index in sidebar

  final List<Map<String, dynamic>> _reportTypes = [
    {
      'value': 'comprehensive',
      'label': 'Comprehensive Report',
      'icon': Icons.analytics,
      'description': 'Complete system overview with all metrics',
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
          _reportData = response['report'];
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
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height -
            100, // Leave space for dashboard app bar
      ),
      child: _buildReportsContent(context, isMobile),
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
                  SizedBox(width: 120, child: _buildGenerateButton()),
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
    final data = _reportData?['data'] as Map<String, dynamic>?;
    final period = _reportData?['period'] as String?;

    if (data == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('Failed to load report data'),
            ],
          ),
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (period != null) _buildReportHeader(context, period),
          const SizedBox(height: 24),
          if (_selectedReportType == 'comprehensive')
            _buildComprehensiveReport(context, data, isMobile)
          else if (_selectedReportType == 'revenue')
            _buildRevenueReport(context, data, isMobile)
          else if (_selectedReportType == 'labs')
            _buildLabsReport(context, data, isMobile)
          else if (_selectedReportType == 'subscriptions')
            _buildSubscriptionsReport(context, data, isMobile),
        ],
      ),
    );
  }

  Widget _buildReportHeader(BuildContext context, String period) {
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');
    final now = DateTime.now();

    // Calculate period text based on period
    String periodText;

    switch (period) {
      case 'daily':
        periodText = 'Today';
        break;
      case 'weekly':
        periodText = 'This Week';
        break;
      case 'monthly':
        periodText = 'This Month';
        break;
      case 'yearly':
        periodText = 'This Year';
        break;
      case 'custom':
        periodText = 'Custom Range';
        break;
      default:
        periodText = 'Last 30 Days';
    }

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
                  Text(periodText, style: const TextStyle(fontSize: 12)),
                  Text(
                    'Generated: ${dateFormat.format(now)}',
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
    final platform = data['platform'] as Map<String, dynamic>? ?? {};

    return Column(
      children: [
        _buildRevenueReport(context, data['revenue'] ?? {}, isMobile),
        const SizedBox(height: 16),
        _buildLabsReport(context, data['labs'] ?? {}, isMobile),
        const SizedBox(height: 16),
        _buildSubscriptionsReport(
          context,
          data['subscriptions'] ?? {},
          isMobile,
        ),
      ],
    );
  }

  Widget _buildRevenueReport(
    BuildContext context,
    Map<String, dynamic> data,
    bool isMobile,
  ) {
    final monthlyRevenue = data['monthlyRevenue'] as List? ?? [];
    final projectedRevenue = data['projectedRevenue'] as List? ?? [];
    final averageRevenuePerLab = data['averageRevenuePerLab'] ?? 0;
    final revenueGrowth = data['revenueGrowth'] ?? 0;

    return Column(
      children: [
        _buildStatCard('Revenue Analysis', [
          _buildStatItem(
            'Average Revenue/Lab',
            '\$$averageRevenuePerLab',
            Icons.account_balance,
            AppTheme.successGreen,
          ),
          _buildStatItem(
            'Revenue Growth',
            '$revenueGrowth%',
            Icons.trending_up,
            revenueGrowth >= 0 ? AppTheme.successGreen : AppTheme.errorRed,
          ),
          _buildStatItem(
            'Monthly Records',
            '${monthlyRevenue.length}',
            Icons.calendar_month,
            AppTheme.primaryBlue,
          ),
          _buildStatItem(
            'Projected Items',
            '${projectedRevenue.length}',
            Icons.schedule,
            AppTheme.secondaryTeal,
          ),
        ], isMobile),
        if (monthlyRevenue.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildRevenueChart(context, monthlyRevenue, isMobile),
        ],
        if (monthlyRevenue.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildTableCard(
            'Monthly Revenue Trend',
            ['Year-Month', 'Revenue', 'Labs Count'],
            monthlyRevenue.map((item) {
              // Handle different _id formats
              String yearMonth;
              if (item['_id'] is Map) {
                final id = item['_id'] as Map<String, dynamic>;
                yearMonth =
                    '${id['year']}-${id['month'].toString().padLeft(2, '0')}';
              } else if (item['_id'] is String) {
                // If _id is a string, use it directly or parse it
                final idStr = item['_id'] as String;
                if (idStr.contains('-')) {
                  yearMonth = idStr;
                } else {
                  yearMonth = idStr;
                }
              } else {
                yearMonth = 'Unknown';
              }

              return [
                yearMonth,
                '\$${item['revenue'] ?? 0}',
                '${item['count'] ?? 0}',
              ];
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildRevenueChart(
    BuildContext context,
    List<dynamic> monthlyRevenue,
    bool isMobile,
  ) {
    // Get responsive breakpoints
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final breakpoints = ResponsiveBreakpoints.of(context);

    // Responsive sizing
    final isTablet = breakpoints.isTablet;
    final isLargeDesktop = screenWidth > 1400;

    // Calculate responsive dimensions
    double chartHeight;
    double barWidth;
    double fontSize;
    double titleFontSize;
    double reservedSizeBottom;
    double reservedSizeLeft;

    if (isMobile) {
      chartHeight = screenHeight * 0.25;
      barWidth = 16;
      fontSize = 12;
      titleFontSize = 14;
      reservedSizeBottom = 30;
      reservedSizeLeft = 50;
    } else if (isTablet) {
      chartHeight = screenHeight * 0.35;
      barWidth = 20;
      fontSize = 14;
      titleFontSize = 16;
      reservedSizeBottom = 35;
      reservedSizeLeft = 65;
    } else if (isLargeDesktop) {
      chartHeight = screenHeight * 0.45;
      barWidth = 32;
      fontSize = 16;
      titleFontSize = 18;
      reservedSizeBottom = 45;
      reservedSizeLeft = 85;
    } else {
      chartHeight = screenHeight * 0.4;
      barWidth = 28;
      fontSize = 15;
      titleFontSize = 17;
      reservedSizeBottom = 40;
      reservedSizeLeft = 75;
    }

    // Prepare data for the chart
    final spots = <FlSpot>[];
    final labels = <String>[];

    for (int i = 0; i < monthlyRevenue.length && i < 12; i++) {
      final item = monthlyRevenue[i];
      final revenue = (item['revenue'] ?? 0).toDouble();

      // Handle different _id formats (could be string or object)
      String label;
      if (item['_id'] is Map) {
        final id = item['_id'] as Map<String, dynamic>;
        label = '${id['month']}/${id['year'].toString().substring(2)}';
      } else if (item['_id'] is String) {
        // If _id is a string, try to parse it
        final idStr = item['_id'] as String;
        if (idStr.contains('-')) {
          final parts = idStr.split('-');
          if (parts.length >= 2) {
            label = '${parts[1]}/${parts[0].substring(2)}';
          } else {
            label = idStr;
          }
        } else {
          label = idStr;
        }
      } else {
        label = 'M${i + 1}';
      }

      spots.add(FlSpot(i.toDouble(), revenue));
      labels.add(label);
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue Trend Chart',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: titleFontSize,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: chartHeight,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: spots.isNotEmpty
                      ? spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) *
                            1.2
                      : 100,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: AppTheme.primaryBlue,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '\$${rod.toY.toStringAsFixed(0)}',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < labels.length) {
                            return Text(
                              labels[index],
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: reservedSizeBottom,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '\$${value.toInt()}',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                        reservedSize: reservedSizeLeft,
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: spots.isNotEmpty
                        ? spots
                                  .map((e) => e.y)
                                  .reduce((a, b) => a > b ? a : b) /
                              5
                        : 20,
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: spots.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.y,
                          color: AppTheme.successGreen,
                          width: barWidth,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabsStatusChart(
    BuildContext context,
    List<dynamic> labsByStatus,
    bool isMobile,
  ) {
    // Get responsive breakpoints
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final breakpoints = ResponsiveBreakpoints.of(context);

    // Responsive sizing
    final isTablet = breakpoints.isTablet;
    final isLargeDesktop = screenWidth > 1400;

    // Calculate responsive dimensions
    double chartHeight;
    double radius;
    double titleFontSize;
    double legendFontSize;
    double centerSpaceRadius;

    if (isMobile) {
      chartHeight = screenHeight * 0.22;
      radius = screenWidth * 0.12;
      titleFontSize = screenWidth * 0.035;
      legendFontSize = 13;
      centerSpaceRadius = 35;
    } else if (isTablet) {
      chartHeight = screenHeight * 0.30;
      radius = screenWidth * 0.09;
      titleFontSize = screenWidth * 0.028;
      legendFontSize = 15;
      centerSpaceRadius = 40;
    } else if (isLargeDesktop) {
      chartHeight =
          screenHeight * 0.30; // Further reduced for better containment
      radius = 100; // Reduced radius for smaller chart
      titleFontSize = 18; // Slightly smaller title
      legendFontSize = 16;
      centerSpaceRadius = 45;
    } else {
      chartHeight = screenHeight * 0.35;
      radius = screenWidth * 0.08;
      titleFontSize = screenWidth * 0.025;
      legendFontSize = 16;
      centerSpaceRadius = 45;
    }

    final colors = [
      AppTheme.successGreen,
      AppTheme.errorRed,
      AppTheme.secondaryTeal,
      AppTheme.accentOrange,
      AppTheme.primaryBlue,
    ];

    // Calculate total for percentages
    final total = labsByStatus.fold<double>(
      0,
      (sum, item) => sum + ((item['count'] ?? 0) as num).toDouble(),
    );

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < labsByStatus.length && i < colors.length; i++) {
      final item = labsByStatus[i];
      final count = (item['count'] ?? 0).toDouble();
      final status = item['_id'] ?? 'Unknown';
      final percentage = total > 0 ? (count / total * 100).round() : 0;

      sections.add(
        PieChartSectionData(
          color: colors[i],
          value: count,
          title: '${count.toInt()}\n$percentage%',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: titleFontSize * 0.8,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.2,
          ),
          badgeWidget: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colors[i],
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors[i].withValues(alpha: 0.3),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          badgePositionPercentageOffset: 0.9,
        ),
      );
    }

    return Card(
      elevation: 4,
      shadowColor: AppTheme.primaryBlue.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              AppTheme.primaryBlue.withValues(alpha: 0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isLargeDesktop ? 32.0 : 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.secondaryTeal.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.science,
                      color: AppTheme.secondaryTeal,
                      size: isLargeDesktop ? 24 : 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Labs by Status Distribution',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: isLargeDesktop
                                    ? 22
                                    : (isMobile ? 16 : 18),
                                color: AppTheme.primaryBlue,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Current status breakdown of all laboratories',
                          style: TextStyle(
                            fontSize: isLargeDesktop ? 14 : 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enhanced Chart Section
                  Expanded(
                    flex: isLargeDesktop
                        ? 2
                        : 2, // Reduced flex for chart on large desktop
                    child: Container(
                      height: chartHeight,
                      margin: EdgeInsets.all(
                        isLargeDesktop ? 16 : 8,
                      ), // Increased margin for large screens
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.all(
                            isLargeDesktop ? 20 : 12,
                          ), // Increased padding for large screens
                          child: PieChart(
                            PieChartData(
                              sections: sections,
                              sectionsSpace: 3,
                              centerSpaceRadius: centerSpaceRadius,
                              centerSpaceColor: Colors.white,
                              borderData: FlBorderData(show: false),
                              pieTouchData: PieTouchData(
                                touchCallback:
                                    (FlTouchEvent event, pieTouchResponse) {
                                      // Add touch feedback if needed
                                    },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isLargeDesktop ? 40 : (isTablet ? 28 : 24)),
                  // Enhanced Legend Section
                  Expanded(
                    flex: isLargeDesktop
                        ? 3
                        : 1, // Increased flex for legend on large desktop
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE0E0E0),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status Breakdown',
                            style: TextStyle(
                              fontSize: isLargeDesktop ? 16 : 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...labsByStatus.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            final status = item['_id'] ?? 'Unknown';
                            final count = item['count'] ?? 0;
                            final percentage = total > 0
                                ? (count / total * 100).round()
                                : 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      (index < colors.length
                                              ? colors[index]
                                              : Colors.grey)
                                          .withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: isLargeDesktop ? 18 : 14,
                                    height: isLargeDesktop ? 18 : 14,
                                    decoration: BoxDecoration(
                                      color: index < colors.length
                                          ? colors[index]
                                          : Colors.grey,
                                      borderRadius: BorderRadius.circular(3),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              (index < colors.length
                                                      ? colors[index]
                                                      : Colors.grey)
                                                  .withValues(alpha: 0.3),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          status,
                                          style: TextStyle(
                                            fontSize: legendFontSize,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                        Text(
                                          '$count labs ($percentage%)',
                                          style: TextStyle(
                                            fontSize: legendFontSize * 0.85,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabsReport(
    BuildContext context,
    Map<String, dynamic> data,
    bool isMobile,
  ) {
    final totalLabs = data['totalLabs'] ?? 0;
    final activeLabs = data['activeLabs'] ?? 0;
    final inactiveLabs = data['inactiveLabs'] ?? 0;
    final labsByStatus = data['labsByStatus'] as List? ?? [];
    final labsBySubscriptionTier =
        data['labsBySubscriptionTier'] as List? ?? [];
    final labsByLocation = data['labsByLocation'] as List? ?? [];

    return Column(
      children: [
        _buildStatCard('Lab Statistics', [
          _buildStatItem(
            'Total Labs',
            '$totalLabs',
            Icons.business,
            AppTheme.primaryBlue,
          ),
          _buildStatItem(
            'Active Labs',
            '$activeLabs',
            Icons.check_circle,
            AppTheme.successGreen,
          ),
          _buildStatItem(
            'Inactive Labs',
            '$inactiveLabs',
            Icons.cancel,
            AppTheme.errorRed,
          ),
          _buildStatItem(
            'Active Rate',
            '${totalLabs > 0 ? ((activeLabs / totalLabs) * 100).round() : 0}%',
            Icons.percent,
            AppTheme.secondaryTeal,
          ),
        ], isMobile),
      ],
    );
  }

  Widget _buildSubscriptionsReport(
    BuildContext context,
    Map<String, dynamic> data,
    bool isMobile,
  ) {
    final totalSubscriptions = data['totalSubscriptions'] ?? 0;
    final activeSubscriptions = data['activeSubscriptions'] ?? 0;
    final expiredSubscriptions = data['expiredSubscriptions'] ?? 0;

    return Column(
      children: [
        _buildStatCard('Subscription Statistics', [
          _buildStatItem(
            'Total Subscriptions',
            '$totalSubscriptions',
            Icons.payment,
            AppTheme.primaryBlue,
          ),
          _buildStatItem(
            'Active',
            '$activeSubscriptions',
            Icons.check_circle,
            AppTheme.successGreen,
          ),
          _buildStatItem(
            'Expired',
            '$expiredSubscriptions',
            Icons.cancel,
            AppTheme.errorRed,
          ),
          _buildStatItem(
            'Active Rate',
            '${totalSubscriptions > 0 ? ((activeSubscriptions / totalSubscriptions) * 100).round() : 0}%',
            Icons.percent,
            AppTheme.secondaryTeal,
          ),
        ], isMobile),
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
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              crossAxisCount: isMobile ? 2 : 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isMobile ? 1.0 : 1.3,
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
    return Builder(
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = ResponsiveBreakpoints.of(context).isMobile;

        // Responsive calculations based on screen size
        final iconSize = isMobile
            ? 24.0
            : (screenWidth * 0.015).clamp(20.0, 32.0);
        final valueFontSize = isMobile
            ? 16.0
            : (screenWidth * 0.012).clamp(14.0, 18.0);
        final labelFontSize = isMobile
            ? 10.0
            : (screenWidth * 0.008).clamp(9.0, 11.0);
        final padding = isMobile
            ? 8.0
            : (screenWidth * 0.006).clamp(10.0, 16.0);
        final spacing = isMobile ? 6.0 : (screenWidth * 0.004).clamp(6.0, 10.0);

        return Container(
          padding: EdgeInsets.all(padding),
          constraints: BoxConstraints(
            minHeight: isMobile ? 80 : 100,
            maxHeight: isMobile ? 120 : 150,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: iconSize),
              SizedBox(height: spacing),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: spacing * 0.5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: labelFontSize,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
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
                headingRowColor: WidgetStateProperty.all(
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
