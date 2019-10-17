abstract class _BasicOperations {
  /// Read the data at [path] once.
  Future<Map<String, dynamic>> read(String path);

  /// Do a partial update instead of overwriting an entire location.
  Future<void> update(String path, Map<String, dynamic> data);

  /// Remove the data at [path].
  Future<void> delete(String path);

  /// Create or overwrite.
  Future<void> write(String path, Map<String, dynamic> data);
}

/// An abstraction of both Firestore and Firebase's real-time database.
abstract class Database implements _BasicOperations {
  const Database();

  /// The underlying database e.g. Firestore or FirebaseDatabase.
  Object get db;

  Future<bool> exists(String path) async => (await read(path)) != null;

  /// Create data where none exists.
  Future<void> create(String path, Map<String, dynamic> data);

  /// Be notified and react to data changes.
  Stream<Map<String, dynamic>> stream(String path);

  // /// Run a transaction. All reads must be performed before any writes.
  // Future<void> transact(TransactionHandler handler,
  //     {Duration timeout = const Duration(seconds: 5)});

  /// Write to various locations atomically (offline friendly).
  // Future<void> batchWrite(BatchHandler handler);

  /// Generate a new ID or key to be used at [path].
  String generateId(String path);

  /// A value that will be converted into the server's timestamp when written.
  dynamic get serverTimestamp;

  static DateTime parseTimestamp(dynamic timestamp) {
    return timestamp == null
        ? null
        : timestamp is int
            ? DateTime.fromMillisecondsSinceEpoch(timestamp)
            : timestamp is String ? DateTime.tryParse(timestamp) : null;
  }

  /// Remove any leading, trailing or repeated slashes.
  static String normalize(String path) {
    if (path.startsWith(pathSep)) path = path.substring(1);
    if (path.endsWith(pathSep)) path = path.substring(0, path.length - 1);
    return path.replaceAll(_multiSep, pathSep);
  }

  static final _multiSep = RegExp('$pathSep+');

  /// Split a path into parts, after calling [Database.normalize(path)].
  static List<String> split(String path) => normalize(path).split(pathSep);

  static String idOf(String path) =>
      path.substring(path.lastIndexOf(pathSep) + 1);
  static String parentOf(String path) =>
      path.substring(0, path.lastIndexOf(pathSep));

  static String pathSep = '/';
}

/// Used by Firestore only.
/// All reads must be done before any writes.
abstract class Transaction implements _BasicOperations {}

/// Used by Firestore only.
abstract class WriteBatch {
  Future<void> commit();

  /// Do a partial update instead of overwriting an entire location.
  void update(String path, Map<String, dynamic> data);

  /// Remove the data at [path].
  void delete(String path);

  /// Create or overwrite.
  void write(String path, Map<String, dynamic> data, {bool merge = false});
}

typedef TransactionHandler = Future<void> Function(Transaction);
typedef BatchHandler = Future<void> Function(WriteBatch);
