import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/sos_bloc.dart';
import 'services/api_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/report_screen.dart';
import 'screens/map_screen.dart';
import 'database/local_database.dart';

void main() {
  // Ensure widget bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  final database = LocalDatabase();
  final apiService = ApiService(database: database);
  runApp(MyApp(apiService: apiService, database: database));
}

class MyApp extends StatelessWidget {
  final ApiService apiService;
  final LocalDatabase database;

  const MyApp({super.key, required this.apiService, required this.database});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<LocalDatabase>.value(value: database),
        RepositoryProvider<ApiService>.value(value: apiService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<SosBloc>(
            create: (context) => SosBloc(apiService: apiService),
          ),
        ],
        child: MaterialApp(
          title: 'Panggil-In Citizen',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF1744),
              brightness: Brightness.dark,
              primary: const Color(0xFFFF1744),
              surface: const Color(0xFF0F1219),
            ),
            fontFamily: 'Inter',
          ),
          initialRoute: '/onboarding',
          routes: {
            '/onboarding': (context) => const OnboardingScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/home': (context) => const HomeScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/lapor': (context) => const ReportScreen(),
            '/pantau': (context) => const MapScreen(),
          },
        ),
      ),
    );
  }
}
