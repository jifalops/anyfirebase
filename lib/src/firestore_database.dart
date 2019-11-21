import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'database.dart';

class FirestoreDatabase extends Database {
  const FirestoreDatabase();

  @override
  fs.Firestore get db => fs.Firestore.instance;

  /// Does not work with collections.
  @override
  Future<void> write(String path, Map<String, dynamic> data,
          {bool merge = false}) =>
      db.document(path).setData(data, merge: merge);

  /// Read and write across documents atomically.
  Future<void> transact(TransactionHandler handler,
          {Duration timeout = const Duration(seconds: 5)}) =>
      db.runTransaction(
          (tx) async => await handler(_FirestoreTransaction(db, tx)),
          timeout: timeout);

  Future<void> batchWrite(BatchHandler handler) =>
      handler(_FirestoreWriteBatch(db, db.batch()));

  @override
  Stream<Map<String, dynamic>> stream(String path) {
    return isCollection(path)
        ? db.collection(path).snapshots().map((snap) => collectionData(snap))
        : db.document(path).snapshots().map((snap) => snap.data);
  }

  DocStreamer streamWithSubcollections(
      String path, Iterable<String> subcollections) {
    return DocStreamer(this, path, subcollections);
  }

  @override
  Future<Map<String, dynamic>> read(String path) async {
    if (isCollection(path)) {
      final snap = await db.collection(path).getDocuments();
      return collectionData(snap);
    } else {
      return (await db.document(path).get()).data;
    }
  }

  /// Update a single document.
  @override
  Future<void> update(String path, Map<String, dynamic> valuesToUpdate) =>
      db.document(path).updateData(valuesToUpdate);

  /// Creates a single document, first checking that it doesn't exist.
  @override
  Future<void> create(String path, Map<String, dynamic> data) async {
    if (await exists(path)) {
      throw Exception('Data already exists at $path');
    } else {
      write(path, data);
    }
  }

  /// Deletes an entire document.
  @override
  Future<void> delete(String path) => db.document(path).delete();

  @override
  String generateId(String path) => db.collection(path).document().documentID;

  @override
  get serverTimestamp => fs.FieldValue.serverTimestamp();

  static bool isCollection(String path) => Database.split(path).length.isOdd;

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
  Future<Map<String, dynamic>> read(String path) async =>
      (await tx.get(db.document(path))).data;

  @override
  Future<void> update(String path, Map<String, dynamic> data) =>
      tx.update(db.document(path), data);

  @override
  Future<void> write(String path, Map<String, dynamic> data) =>
      tx.set(db.document(path), data);
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
  void update(String path, Map<String, dynamic> data) =>
      batch.updateData(db.document(path), data);

  @override
  void write(String path, Map<String, dynamic> data, {bool merge = false}) =>
      batch.setData(db.document(path), data, merge: merge);
}

/// Holds the streams of a document and its subcollections.
class DocStreamer {
  DocStreamer(FirestoreDatabase db, String path, Iterable<String> collections)
      : doc = db.stream(path),
        collections = Map.fromIterable(collections,
            value: (item) => db.stream('$path/$item'));
  final Stream<Map<String, dynamic>> doc;
  final Map<String, Stream<Map<String, dynamic>>> collections;
}
