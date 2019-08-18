import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'database.dart';

class FirestoreDatabase extends Database {
  const FirestoreDatabase();

  @override
  fs.Firestore get db => fs.Firestore.instance;

  /// Does not work with collections.
  @override
  Future<void> write(Data data, {bool merge = false}) =>
      db.document(data.path).setData(data.value, merge: merge);

  /// Read and write across documents atomically.
  Future<void> transact(TransactionHandler handler,
          {Duration timeout = const Duration(seconds: 5)}) =>
      db.runTransaction((tx) => handler(_FirestoreTransaction(db, tx)),
          timeout: timeout);

  @override
  Future<void> batchWrite(BatchHandler handler) =>
      handler(_FirestoreWriteBatch(db, db.batch()));

  @override
  Stream<Data> stream(String path, {bool filterNull = true}) {
    return isCollection(path)
        ? db
            .collection(path)
            .snapshots()
            .map((snap) => Data(path, collectionData(snap)))
        : filterNull
            ? db
                .document(path)
                .snapshots()
                .where((snap) => snap.data != null)
                .map((snap) => Data(path, snap.data))
            : db
                .document(path)
                .snapshots()
                .map((snap) => Data(path, snap.data));
  }

  @override
  Future<Data> read(String path) async {
    if (isCollection(path)) {
      final snap = await db.collection(path).getDocuments();
      return Data(path, collectionData(snap));
    } else {
      return Data(path, (await db.document(path).get()).data);
    }
  }

  /// Update a single document.
  @override
  Future<void> update(Data valuesToUpdate) =>
      db.document(valuesToUpdate.path).updateData(valuesToUpdate.value);

  /// Creates a single document, first checking that it doesn't exist.
  @override
  Future<void> create(Data data) => transact((tx) async {
        if (await tx.read(data.path) == null) {
          tx.write(data);
        } else {
          throw Exception('Data already exists at ${data.path}');
        }
      });

  /// Deletes an entire document.
  @override
  Future<void> delete(String path) => db.document(path).delete();

  @override
  String generateId(String path) => db.collection(path).document().documentID;

  @override
  get serverTimestamp => fs.FieldValue.serverTimestamp();

  static bool isCollection(String path) =>
      Database.splitPath(path).length.isOdd;

  static Map<String, dynamic> collectionData(fs.QuerySnapshot snap) =>
      snap.documents
          .asMap()
          .map((i, doc) => MapEntry(doc.documentID, doc.data));
}

class _FirestoreTransaction extends Transaction {
  _FirestoreTransaction(this.db, this.tx);
  final fs.Firestore db;
  final fs.Transaction tx;

  @override
  Future<void> delete(String path) => tx.delete(db.document(path));

  @override
  Future<Data> read(String path) async =>
      Data(path, (await tx.get(db.document(path))).data);

  @override
  Future<void> update(Data data) =>
      tx.update(db.document(data.path), data.value);

  @override
  Future<void> write(Data data) => tx.set(db.document(data.path), data.value);
}

class _FirestoreWriteBatch extends WriteBatch {
  _FirestoreWriteBatch(this.db, this.batch);
  final fs.Firestore db;
  final fs.WriteBatch batch;

  @override
  Future<void> commit() => batch.commit();

  @override
  void delete(String path) => batch.delete(db.document(path));

  @override
  void update(Data data) =>
      batch.updateData(db.document(data.path), data.value);

  @override
  void write(Data data, {bool merge = false}) =>
      batch.setData(db.document(data.path), data.value, merge: merge);
}
