import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'services/desktop_api_service.dart';
import 'providers/pairing_provider.dart';
import 'providers/usage_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/pairing/pairing_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.surface,
    ),
  );
  runApp(const TraceApp());
}

class TraceApp extends StatelessWidget {
  const TraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final apiService = DesktopApiService();
    final pairingProvider = PairingProvider(apiService);
    final usageProvider = UsageProvider(apiService)
      ..setPairingProvider(pairingProvider);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: pairingProvider),
        ChangeNotifierProvider.value(value: usageProvider),
      ],
      child: MaterialApp(
        title: 'Trace Your Lyf',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/home': (context) => const HomeScreen(),
          '/pairing': (context) => const PairingScreen(),
        },
      ),
    );
  }
}
