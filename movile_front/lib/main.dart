import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/vehicle_form_screen.dart';
import 'screens/vehicle_management_screen.dart';
import 'screens/emergency_form_screen.dart';
import 'screens/emergency_list_screen.dart';
import 'screens/rental_vehicles_list_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/technician_access_screen.dart';
import 'screens/technician_dashboard_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/payment_success_screen.dart';
import 'screens/emergency_offline_screen.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/technician_access_service.dart';
import 'services/mobile_notification_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => TechnicianAccessService()),
        ChangeNotifierProxyProvider<AuthService, MobileNotificationService>(
          create: (_) => MobileNotificationService(),
          update: (_, authService, notificationService) {
            final service = notificationService ?? MobileNotificationService();
            service.updateAuth(authService);
            return service;
          },
        ),
        Provider(create: (_) => ApiService()),
      ],
      child: MaterialApp(
        title: 'AutoGo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          primaryColor: const Color(0xFF3B82F6),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF3B82F6),
            elevation: 0,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        initialRoute: '/login',
        onGenerateRoute: (settings) {
          final routeName = settings.name ?? '/login';
          final uri = Uri.tryParse(routeName);
          final path = uri?.path ?? routeName;

          if (path == '/payment-success') {
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => PaymentSuccessScreen(
                paymentId: uri?.queryParameters['payment_id'],
                sessionId: uri?.queryParameters['session_id'],
              ),
            );
          }

          if (path == '/payment-cancel') {
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => const EmergencyListScreen(),
            );
          }

          return null;
        },
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreen(),
          '/profile': (context) => const UserProfileScreen(),
          '/vehicles': (context) => const VehicleManagementScreen(),
          '/vehicle-form': (context) => const VehicleFormScreen(),
          '/emergency-form': (context) => const EmergencyFormScreen(),
          '/emergency-list': (context) => const EmergencyListScreen(),
          '/rental-vehicles': (context) => const RentalVehiclesListScreen(),
          '/technician/access': (context) => const TechnicianAccessScreen(),
          '/technician/dashboard': (context) => const TechnicianDashboardScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/payment-success': (context) => const PaymentSuccessScreen(),
          '/payment-cancel': (context) => const EmergencyListScreen(),
          '/emergency-offline': (context) => const EmergencyOfflineScreen(),
        },
      ),
    );
  }
}
