import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'services/dispatch_service.dart';
import 'bloc/dashboard_bloc.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_shell.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  final dispatchService = DispatchService();
  final dashboardBloc = DashboardBloc(dispatchService: dispatchService);

  runApp(MyApp(
    dashboardBloc: dashboardBloc,
  ));
}

class MyApp extends StatelessWidget {
  final DashboardBloc dashboardBloc;

  const MyApp({
    super.key,
    required this.dashboardBloc,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardBloc>.value(
      value: dashboardBloc,
      child: MaterialApp(
        title: 'Panggil-In SIGAP Dispatcher',
        debugShowCheckedModeBanner: false,
        theme: SigapTheme.darkTheme,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const DashboardShell(),
        },
      ),
    );
  }
}
