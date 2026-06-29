import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/services/api_service.dart';
import 'package:mobile_app/database/local_database.dart';

void main() {
  testWidgets('App loads home screen smoke test', (WidgetTester tester) async {
    final database = LocalDatabase();
    final apiService = ApiService(database: database);
    await tester.pumpWidget(MyApp(apiService: apiService, database: database));

    // Verify that our home screen renders with SOS button text
    expect(find.text('SOS BEGAL!'), findsOneWidget);
  });
}
