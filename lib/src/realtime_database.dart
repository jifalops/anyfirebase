import 'package:firebase_database/firebase_database.dart' as rt;
import 'database.dart';

Map<String, dynamic> _cast(dynamic value) =>
    value == null ? null : Map<String, dynamic>.from(value);

class RealtimeDatabase extends Database {
  const RealtimeDatabase();

  @override
  rt.DatabaseReference get db => rt.FirebaseDatabase.instance.reference();

  @override
  Stream<Data> stream(String path, {bool filterNull = false}) {
    return filterNull
        ? db
            .child(path)
            .onValue
            .where((event) => event.snapshot.value != null)
            .map((event) => Data(path, _cast(event.snapshot.value)))
        : db
            .child(path)
            .onValue
            .map((event) => Data(path, _cast(event.snapshot.value)));
  }

  @override
  Future<Data> read(
    String path,
  ) async =>
      Data(path, _cast((await db.child(path).once()).value));

  /// Altough this is a simpler alternative to [batchWrite()], this should only
  /// be used to modify a single location so that differences in Firestore and
  /// the real-time database can be abstracted away.
  @override
  Future<void> update(Data valuesToUpdate) =>
      db.child(valuesToUpdate.path).update(valuesToUpdate.value);

  @override
  Future<void> batchWrite(BatchHandler handler) => handler(_RtdbWriteBatch(db));

  Future<void> create(Data data) async {
    if (await exists(data.path)) {
      throw Exception('Data already exists at ${data.path}');
    } else {
      write(data);
    }
  }

  @override
  Future<void> delete(String path) => db.child(path).remove();

  @override
  String generateId([String path = '']) => db.child(path).push().key;

  @override
  get serverTimestamp => rt.ServerValue.timestamp;

  Future<Data> transact(String path, Future<Data> Function(Data) handler,
      {Duration timeout = const Duration(seconds: 5)}) async {
    final result = await db.child(path).runTransaction((data) async {
      final newData = await handler(Data(path, data.value));
      data.value = newData.value;
      return data;
    }, timeout: timeout);
    if (result.error != null) {
      throw result.error;
    } else if (result.committed == false) {
      throw Exception('Transaction failed');
    } else {
      return Data(path, result.dataSnapshot.value);
    }
  }

  @override
  Future<void> write(Data data) => db.child(data.path).set(data.value);
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
  void update(Data data) => _updates[data.path] = data.value;

  /// Alias for [update()] because of potential performance issues.
  ///
  /// TODO: The real-time database doesn't actually support this unless [commit()]
  /// creates a transaction. But, the transaction would read the data at the
  /// lowest common denominator path of the batch writes. If the writes don't
  /// all share a top-level branch, the entire database would have to be read.
  ///
  /// For the same reason, [Database.transact()] cannot exist.
  @override
  void write(Data data) => update(data);
}
