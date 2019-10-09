// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DatabaseProfileData _$DatabaseProfileDataFromJson(Map<String, dynamic> json) {
  return DatabaseProfileData(
    displayName: json['displayName'] as String,
    photoUrl: json['photoUrl'] as String,
  );
}

Map<String, dynamic> _$DatabaseProfileDataToJson(
        DatabaseProfileData instance) =>
    <String, dynamic>{
      'displayName': instance.displayName,
      'photoUrl': instance.photoUrl,
    };
