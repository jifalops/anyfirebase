import 'package:json_annotation/json_annotation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quiver/core.dart';
import 'database.dart';

part 'database_profile.g.dart';

class DatabaseProfile {
  DatabaseProfile(this._db, String path)
      : _path = Database.normalize(path),
        uid = Database.idOf(path);
  final Database _db;
  final String _path;
  final String uid;

  Stream<DatabaseProfileData> get stream => _db.stream(_path).map((data) =>
      data?.value == null ? null : DatabaseProfileData.fromJson(data.value));

  Future<bool> get exists => _db.exists(_path);

  Future<void> create(DatabaseProfileData data) =>
      _db.write(Data(_path, data.toJson()));

  Future<void> delete() => _db.delete(_path);

  Future<void> updateDisplayName(String displayName) =>
      _db.update(Data(_path, {'displayName': displayName}));
  Future<void> updatephotoUrl(String photoUrl) =>
      _db.update(Data(_path, {'photoUrl': photoUrl}));

  @override
  String toString() => '$runtimeType at "$_path" in a ${_db.runtimeType}';

  bool operator ==(o) =>
      o is DatabaseProfile && _db == o?._db && _path == o?._path;
  int get hashCode => hash2(_db, _path);
}

/// [FirebaseUser] info added to the user's public profile in the database.
@JsonSerializable(nullable: false)
class DatabaseProfileData {
  const DatabaseProfileData({this.displayName, this.photoUrl});
  DatabaseProfileData.fromUser(FirebaseUser user)
      : displayName = user.displayName,
        photoUrl = user.photoUrl;
  factory DatabaseProfileData.fromJson(Map<String, dynamic> json) =>
      _$DatabaseProfileDataFromJson(json);
  Map<String, dynamic> toJson() => _$DatabaseProfileDataToJson(this);

  final String displayName;
  final String photoUrl;

  @override
  String toString() => toJson().toString();

  bool operator ==(o) =>
      o is DatabaseProfileData &&
      displayName == o.displayName &&
      photoUrl == o.photoUrl;
  int get hashCode => hash2(displayName, photoUrl);
}
