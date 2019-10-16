import 'database.dart';
import 'package:rxdart/rxdart.dart';

class DataStream<T> {
  factory DataStream(
      Database db, String path, T Function(Map<String, dynamic>) mapper,
      [T initialData]) {
    if (_instances.containsKey(T)) {
      return _instances[T].putIfAbsent(Database.idOf(path),
          () => DataStream._(db, path, mapper, initialData));
    } else {
      final instance = DataStream._(db, path, mapper, initialData);
      _instances[T] = <String, DataStream>{Database.idOf(path): instance};
      return instance;
    }
  }
  static final _instances = <Type, Map<String, DataStream>>{};

  DataStream._(
      Database db, String path, T Function(Map<String, dynamic>) mapper,
      [T initialData])
      : _controller = initialData == null
            ? BehaviorSubject()
            : BehaviorSubject.seeded(initialData) {
    _controller.addStream(db.stream(path).map(mapper));
  }
  final BehaviorSubject<T> _controller;

  T get data => _controller.value;
  Stream<T> get stream => _controller.stream;
  bool get hasData => data != null;
}
