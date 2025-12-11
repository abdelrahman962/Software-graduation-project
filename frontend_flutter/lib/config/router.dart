import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/marketing/home_screen.dart';
import '../screens/marketing/about_screen.dart';
import '../screens/marketing/services_screen.dart';
import '../screens/marketing/contact_screen.dart';
import '../screens/common/merged_login_screen.dart';
import '../screens/public/public_registration_screen.dart';
import '../screens/public/lab_finder_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/staff/staff_dashboard_screen.dart';
import '../screens/patient/patient_dashboard_screen.dart';
import '../screens/patient/patient_order_report_screen.dart';
import '../screens/doctor/doctor_dashboard_screen.dart';
import '../screens/doctor/patient_details_screen.dart';
import '../screens/doctor/doctor_feedback_screen.dart';
import '../screens/doctor/doctor_patient_report_screen.dart';
import '../screens/patient/patient_feedback_screen.dart';
import '../screens/staff/staff_feedback_screen.dart';
import '../screens/owner/owner_dashboard_screen.dart';

import '../screens/owner/inventory_management_screen.dart';
import '../screens/owner/owner_order_management_screen.dart';
import '../screens/owner/reports_screen.dart';
import '../screens/owner/notifications_screen.dart';
import '../screens/owner/audit_logs_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      // Marketing Pages
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/services',
        name: 'services',
        builder: (context, state) => const ServicesScreen(),
      ),
      GoRoute(
        path: '/contact',
        name: 'contact',
        builder: (context, state) => const ContactScreen(),
      ),

      // Admin Routes
      // Unified Login Route
      GoRoute(
        path: '/login',
        name: 'merged-login',
        builder: (context, state) => const MergedLoginScreen(),
      ),

      // Admin Dashboard Route
      GoRoute(
        path: '/admin/dashboard',
        name: 'admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),

      // Staff Dashboard Route
      GoRoute(
        path: '/staff/dashboard',
        name: 'staff-dashboard',
        builder: (context, state) => const StaffDashboardScreen(),
      ),

      // Staff Feedback Route
      GoRoute(
        path: '/staff/feedback',
        name: 'staff-feedback',
        builder: (context, state) => const StaffFeedbackScreen(),
      ),

      // Patient Dashboard Route
      GoRoute(
        path: '/patient-dashboard',
        name: 'patient-dashboard',
        builder: (context, state) => const PatientDashboardScreen(),
        routes: [
          // Patient Order Report Route
          GoRoute(
            path: 'order-report/:orderId',
            name: 'patient-order-report',
            builder: (context, state) {
              final orderId = state.pathParameters['orderId']!;
              return PatientOrderReportScreen(orderId: orderId);
            },
          ),
        ],
      ),

      // Patient Feedback Route
      GoRoute(
        path: '/patient/feedback',
        name: 'patient-feedback',
        builder: (context, state) => const PatientFeedbackScreen(),
      ),

      // Doctor Dashboard Route
      GoRoute(
        path: '/doctor-dashboard',
        name: 'doctor-dashboard',
        builder: (context, state) => const DoctorDashboardScreen(),
        routes: [
          // Doctor Patient Report Route
          GoRoute(
            path: 'patient-report/:orderId',
            name: 'doctor-patient-report',
            builder: (context, state) {
              final orderId = state.pathParameters['orderId']!;
              return DoctorPatientReportScreen(orderId: orderId);
            },
          ),
        ],
      ),

      // Doctor Feedback Route
      GoRoute(
        path: '/doctor/feedback',
        name: 'doctor-feedback',
        builder: (context, state) => const DoctorFeedbackScreen(),
      ),

      // Doctor Patient Details Route
      GoRoute(
        path: '/doctor/patient/:id',
        name: 'doctor-patient-details',
        builder: (context, state) {
          final patientId = state.pathParameters['id'];
          // For now, pass empty patient data - will be loaded in the screen
          return PatientDetailsScreen(patient: {'_id': patientId});
        },
      ),

      // Owner Dashboard Route
      GoRoute(
        path: '/owner/dashboard',
        name: 'owner-dashboard',
        builder: (context, state) => const OwnerDashboardScreen(),
      ),

      // Owner Staff Route
      GoRoute(
        path: '/owner/staff',
        name: 'owner-staff',
        builder: (context, state) => const OwnerDashboardScreen(initialTab: 1),
      ),

      // Owner Doctors Route
      GoRoute(
        path: '/owner/doctors',
        name: 'owner-doctors',
        builder: (context, state) => const OwnerDashboardScreen(initialTab: 2),
      ),

      // Owner Tests Route
      GoRoute(
        path: '/owner/tests',
        name: 'owner-tests',
        builder: (context, state) => const OwnerDashboardScreen(initialTab: 3),
      ),

      // Owner Inventory Route
      GoRoute(
        path: '/owner/inventory',
        name: 'owner-inventory',
        builder: (context, state) => const InventoryManagementScreen(),
      ),

      // Owner Orders Route
      GoRoute(
        path: '/owner/orders',
        name: 'owner-orders',
        builder: (context, state) => const OwnerOrderManagementScreen(),
      ),

      // Owner Reports Route
      GoRoute(
        path: '/owner/reports',
        name: 'owner-reports',
        builder: (context, state) => const ReportsScreen(),
      ),

      // Owner Notifications Route
      GoRoute(
        path: '/owner/notifications',
        name: 'owner-notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // Owner Audit Logs Route
      GoRoute(
        path: '/owner/audit-logs',
        name: 'owner-audit-logs',
        builder: (context, state) => const AuditLogsScreen(),
      ),

      // Dashboards and other routes remain
      // Public Routes
      GoRoute(
        path: '/public/register',
        name: 'public-register',
        builder: (context, state) => const PublicRegistrationScreen(),
      ),
      GoRoute(
        path: '/public/labs',
        name: 'lab-finder',
        builder: (context, state) => const LabFinderScreen(),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page Not Found',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}
