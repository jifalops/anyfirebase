import 'package:firebase_database/firebase_database.dart' as rt;
import 'database.dart';

Map<String, dynamic> _cast(dynamic value) =>
    value == null ? null : Map<String, dynamic>.from(value);

class RealtimeDatabase extends Database {
  const RealtimeDatabase();

  @override
  rt.DatabaseReference get db => rt.FirebaseDatabase.instance.reference();

  @override
  Stream<Map<String, dynamic>> stream(String path, {bool filterNull = false}) {
    return filterNull
        ? db
            .child(path)
            .onValue
            .where((event) => event.snapshot.value != null)
            .map((event) => _cast(event.snapshot.value))
        : db.child(path).onValue.map((event) => _cast(event.snapshot.value));
  }

  @override
  Future<Map<String, dynamic>> read(
    String path,
  ) async =>
      _cast((await db.child(path).once()).value);

  /// Altough this is a simpler alternative to [batchWrite()], this should only
  /// be used to modify a single location so that differences in Firestore and
  /// the real-time database can be abstracted away.
  @override
  Future<void> update(String path, valuesToUpdate) =>
      db.child(path).update(valuesToUpdate);

  @override
  Future<void> batchWrite(BatchHandler handler) => handler(_RtdbWriteBatch(db));

  Future<void> create(String path, Map<String, dynamic> data) async {
    if (await exists(path)) {
      throw Exception('Data already exists at $path');
    } else {
      write(path, data);
    }
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
}

class _RtdbWriteBatch extends WriteBatch {
  _RtdbWriteBatch(this.db);
  final rt.DatabaseReference db;
  final _updates = Map<String, dynamic>();

  @override
  Future<void> commit() => db.update(_updates);

  @override
  void delete(String path) => _updates[path] = null;

  @override
  void update(String path, Map<String, dynamic> data) => _updates[path] = data;

  /// Alias for [update()] because of potential performance issues.
  ///
  /// TODO: The real-time database doesn't actually support this unless [commit()]
  /// creates a transaction. But, the transaction would read the data at the
  /// lowest common denominator path of the batch writes. If the writes don't
  /// all share a top-level branch, the entire database would have to be read.
  ///
  /// For the same reason, [Database.transact()] cannot exist.
  @override
  void write(String path, Map<String, dynamic> data) => update(path, data);
}
