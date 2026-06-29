import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_app/main.dart';
import 'package:desktop_app/services/dispatch_service.dart';
import 'package:desktop_app/bloc/dashboard_bloc.dart';

void main() {
  testWidgets('SIGAP application smoke test', (WidgetTester tester) async {
    final dispatchService = DispatchService();
    final dashboardBloc = DashboardBloc(dispatchService: dispatchService);

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(dashboardBloc: dashboardBloc));

    // Verify that login screen text is present.
    expect(find.text('PANGGIL-IN'), findsOneWidget);
    expect(find.text('LOG IN OPERATOR'), findsOneWidget);
  });
}
