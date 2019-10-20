import 'package:firebase_database/firebase_database.dart' as rt;
import 'database.dart';

class RealtimeDatabase extends Database {
  const RealtimeDatabase();

  @override
  rt.DatabaseReference get db => rt.FirebaseDatabase.instance.reference();

  @override
  Stream<Map<String, dynamic>> stream(String path) {
    return db.child(path).onValue.map((event) => _cast(event.snapshot.value));
  }

  Stream<dynamic> streamValue(String path) {
    return db.child(path).onValue.map((event) => event.snapshot.value);
  }

  @override
  Future<Map<String, dynamic>> read(
    String path,
  ) async =>
      _cast((await db.child(path).once()).value);

  Future<dynamic> readValue(String path) async =>
      (await db.child(path).once()).value;

  /// Altough this is a simpler alternative to [batchWrite()], this should only
  /// be used to modify a single location so that differences in Firestore and
  /// the real-time database can be abstracted away.
  @override
  Future<void> update(String path, Map<String, dynamic> valuesToUpdate) =>
      db.child(path).update(valuesToUpdate);

  Future<void> create(String path, Map<String, dynamic> data) async {
    transact(path, (existing) async {
      return existing == null ? data : null;
    });
  }

  Future<void> createValue(String path, dynamic value) async {
    transact(path, (existing) async {
      return existing == null ? value : null;
    });
  }

  @override
  Future<void> delete(String path) => db.child(path).remove();

  @override
  String generateId([String path = '']) => db.child(path).push().key;

  @override
  get serverTimestamp => rt.ServerValue.timestamp;

  Future<Map<String, dynamic>> transact(String path,
      Future<Map<String, dynamic>> Function(Map<String, dynamic>) handler,
      {Duration timeout = const Duration(seconds: 5)}) async {
    final result = await db.child(path).runTransaction((data) async {
      final newData = await handler(_cast(data.value));
      data.value = newData;
      return data;
    }, timeout: timeout);
    if (result.error != null) {
      throw result.error;
    } else if (result.committed == false) {
      throw Exception('Transaction failed');
    } else {
      return _cast(result.dataSnapshot.value);
    }
  }

  Future<dynamic> transactValue(
      String path, Future<dynamic> Function(dynamic) handler,
      {Duration timeout = const Duration(seconds: 5)}) async {
    final result = await db.child(path).runTransaction((data) async {
      final newData = await handler(data.value);
      data.value = newData;
      return data;
    }, timeout: timeout);
    if (result.error != null) {
      throw result.error;
    } else if (result.committed == false) {
      throw Exception('Transaction failed');
    } else {
      return result.dataSnapshot.value;
    }
  }

  @override
  Future<void> write(String path, Map<String, dynamic> data) =>
      db.child(path).set(data);

  Future<void> writeValue(String path, dynamic value) =>
      db.child(path).set(value);
}

Map<String, dynamic> _cast(dynamic value) =>
    value == null ? null : Map<String, dynamic>.from(value);
