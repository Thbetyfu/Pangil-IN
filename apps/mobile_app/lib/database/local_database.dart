import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:flutter/foundation.dart';

part 'local_database.g.dart';

class CachedReports extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get description => text()();
  TextColumn get status => text()();
  TextColumn get urgency => text()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class EmergencyContacts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get relation => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedReports, EmergencyContacts])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Seed initial emergency contacts
          await into(emergencyContacts).insert(const EmergencyContact(
            id: 'init-1',
            name: 'Ibu (Rumah)',
            phone: '081298765432',
            relation: 'Emergency',
          ));
          await into(emergencyContacts).insert(const EmergencyContact(
            id: 'init-2',
            name: 'Polsek Coblong',
            phone: '0222502218',
            relation: 'Emergency',
          ));
        },
      );

  // CachedReports CRUD Helpers
  Future<List<CachedReport>> getAllReports() => select(cachedReports).get();
  Stream<List<CachedReport>> watchAllReports() => select(cachedReports).watch();
  Future<void> insertReport(CachedReport report) => into(cachedReports).insertOnConflictUpdate(report);
  Future<void> clearAllReports() => delete(cachedReports).go();

  // EmergencyContacts CRUD Helpers
  Future<List<EmergencyContact>> getAllContacts() => select(emergencyContacts).get();
  Stream<List<EmergencyContact>> watchAllContacts() => select(emergencyContacts).watch();
  Future<void> insertContact(EmergencyContact contact) => into(emergencyContacts).insertOnConflictUpdate(contact);
  Future<void> deleteContact(String contactId) => (delete(emergencyContacts)..where((tbl) => tbl.id.equals(contactId))).go();
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    if (kIsWeb) {
      return SqfliteQueryExecutor.inMemory();
    }
    return SqfliteQueryExecutor(path: 'panggilin_local.db', logStatements: kDebugMode);
  });
}
