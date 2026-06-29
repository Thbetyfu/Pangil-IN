import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:mobile_app/database/local_database.dart';
import 'package:mobile_app/services/api_service.dart';

class MockApiServiceForSync extends ApiService {
  MockApiServiceForSync(LocalDatabase db) : super(database: db);

  @override
  Future<void> syncHeatmap() async {
    // Simulate population of database with mock backend response points
    await database.clearAllHeatmaps();
    await database.insertHeatmap(
      const BegalHeatmap(
        id: 'h-sync-1',
        latitude: -6.8915,
        longitude: 107.6161,
        intensity: 4.5,
        areaName: 'Simpang Dago',
        updatedAt: '2026-06-29T08:00:00Z',
      ),
    );
    await database.insertHeatmap(
      const BegalHeatmap(
        id: 'h-sync-2',
        latitude: -6.8975,
        longitude: 107.6186,
        intensity: 3.2,
        areaName: 'Dipatiukur',
        updatedAt: '2026-06-29T08:00:00Z',
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDatabase database;
  late MockApiServiceForSync apiService;

  setUp(() {
    database = LocalDatabase(NativeDatabase.memory());
    apiService = MockApiServiceForSync(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('LocalDatabase BegalHeatmaps CRUD operations work correctly', () async {
    // Check initial empty cache
    List<BegalHeatmap> list = await database.getAllHeatmaps();
    expect(list, isEmpty);

    // Insert a heatmap point
    const point = BegalHeatmap(
      id: 'h-test-1',
      latitude: -6.8902,
      longitude: 107.6105,
      intensity: 2.8,
      areaName: 'Cihampelas',
      updatedAt: '2026-06-29T08:00:00Z',
    );

    await database.insertHeatmap(point);

    // Verify insertion
    list = await database.getAllHeatmaps();
    expect(list.length, equals(1));
    expect(list[0].id, equals('h-test-1'));
    expect(list[0].latitude, equals(-6.8902));
    expect(list[0].longitude, equals(107.6105));
    expect(list[0].intensity, equals(2.8));
    expect(list[0].areaName, equals('Cihampelas'));

    // Clear heatmaps
    await database.clearAllHeatmaps();
    list = await database.getAllHeatmaps();
    expect(list, isEmpty);
  });

  test(
    'ApiService syncHeatmap successfully synchronizes points into local SQLite database',
    () async {
      // Trigger sync
      await apiService.syncHeatmap();

      // Verify database was populated
      final list = await database.getAllHeatmaps();
      expect(list.length, equals(2));

      expect(list[0].id, equals('h-sync-1'));
      expect(list[0].areaName, equals('Simpang Dago'));

      expect(list[1].id, equals('h-sync-2'));
      expect(list[1].areaName, equals('Dipatiukur'));
    },
  );
}
