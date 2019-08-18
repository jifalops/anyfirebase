abstract class _BasicOperations {
  /// Read the data at [path] once.
  Future<Data> read(String path);

  /// Do a partial update instead of overwriting an entire location.
  Future<void> update(Data data);

  /// Remove the data at [path].
  Future<void> delete(String path);

  /// Create or overwrite.
  Future<void> write(Data data);
}

/// An abstraction of both Firestore and Firebase's real-time database.
abstract class Database implements _BasicOperations {
  const Database();

  /// The underlying database e.g. Firestore or FirebaseDatabase.
  Object get db;

  Future<bool> exists(String path) async => (await read(path)).value != null;

  /// Create data where none exists.
  ///
  /// **This will run a transaction to check for existance first.**
  Future<void> create(Data data);

  /// Be notified and react to data changes.
  Stream<Data> stream(String path, {bool filterNull = true});

  // /// Run a transaction. All reads must be performed before any writes.
  // Future<void> transact(TransactionHandler handler,
  //     {Duration timeout = const Duration(seconds: 5)});

  /// Write to various locations atomically (offline friendly).
  Future<void> batchWrite(BatchHandler handler);

  /// Generate a new ID or key to be used at [path].
  String generateId(String path);

  /// A value that will be converted into the server's timestamp when written.
  dynamic get serverTimestamp;

  /// Remove any leading or trailing slash.
  static String normalize(String path) {
    if (path.startsWith(pathSep)) path = path.substring(1);
    if (path.endsWith(pathSep)) path = path.substring(0, path.length - 1);
    return path;
  }

  /// Split a path into parts, after calling [Database.normalize(path)].
  static List<String> splitPath(String path) => normalize(path).split(pathSep);

  static const pathSep = '/';
}

/// Data at a database location.
class Data {
  const Data(this.path, this.value);
  final String path;
  final Map<String, dynamic> value;
  String get id => path.substring(path.lastIndexOf(Database.pathSep) + 1);
  String get parent => path.substring(0, path.lastIndexOf(Database.pathSep));
}

/// All reads must be done before any writes.
abstract class Transaction implements _BasicOperations {}

abstract class WriteBatch {
  Future<void> commit();

  /// Do a partial update instead of overwriting an entire location.
  void update(Data data);

  /// Remove the data at [path].
  void delete(String path);

  /// Create or overwrite.
  void write(Data data);
}

typedef TransactionHandler = Future<void> Function(Transaction);
typedef BatchHandler = Future<void> Function(WriteBatch);
