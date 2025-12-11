import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'providers/auth_provider.dart';
import 'providers/owner_auth_provider.dart';
import 'providers/staff_auth_provider.dart';
import 'providers/doctor_auth_provider.dart';
import 'providers/patient_auth_provider.dart';
import 'providers/marketing_provider.dart';
import 'widgets/common/devtools_adaptive_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure proper viewport handling
  if (kIsWeb) {
    html.document.body?.style.margin = '0';
    html.document.body?.style.padding = '0';
    html.document.body?.style.overflow = 'hidden';
    html.document.body?.style.height = '100vh';
    html.document.body?.style.width = '100vw';
  }

  // Preload all auth providers
  final authProvider = AuthProvider();
  await authProvider.loadAuthState();
  final ownerAuthProvider = OwnerAuthProvider();
  await ownerAuthProvider.loadAuthState();
  final staffAuthProvider = StaffAuthProvider();
  await staffAuthProvider.loadAuthState();
  final doctorAuthProvider = DoctorAuthProvider();
  await doctorAuthProvider.loadAuthState();
  final patientAuthProvider = PatientAuthProvider();
  await patientAuthProvider.loadAuthState();

  runApp(
    DevToolsAdaptiveWrapper(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => authProvider),
          ChangeNotifierProvider(create: (_) => ownerAuthProvider),
          ChangeNotifierProvider(create: (_) => staffAuthProvider),
          ChangeNotifierProvider(create: (_) => doctorAuthProvider),
          ChangeNotifierProvider(create: (_) => patientAuthProvider),
          ChangeNotifierProvider(create: (_) => MarketingProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveBreakpoints.builder(
      child: Builder(
        builder: (context) => MediaQuery(
          // Handle viewport changes for dev tools
          data: MediaQuery.of(
            context,
          ).copyWith(viewInsets: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
          child: MaterialApp.router(
            title: 'Medical Lab Management System',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.router,
          ),
        ),
      ),
      breakpoints: [
        const Breakpoint(start: 0, end: 480, name: MOBILE),
        const Breakpoint(start: 481, end: 1435, name: TABLET),
        const Breakpoint(start: 1436, end: double.infinity, name: DESKTOP),
      ],
    );
  }
}
