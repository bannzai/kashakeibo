import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:freezed_annotation/freezed_annotation.dart';

/// Firestore の [Timestamp] と Dart の [DateTime] を相互変換するコンバータ。
///
/// 必須フィールド用。nullable な場合は [NullableTimestampConverter] を使用する。
class TimestampConverter implements JsonConverter<DateTime, Timestamp> {
  const TimestampConverter();

  @override
  DateTime fromJson(Timestamp json) {
    return json.toDate();
  }

  @override
  Timestamp toJson(DateTime dateTime) {
    return Timestamp.fromDate(dateTime);
  }
}

/// Firestore の [Timestamp] と Dart の [DateTime] を相互変換する nullable 版コンバータ。
class NullableTimestampConverter
    implements JsonConverter<DateTime?, Timestamp?> {
  const NullableTimestampConverter();

  @override
  DateTime? fromJson(Timestamp? json) {
    return json?.toDate();
  }

  @override
  Timestamp? toJson(DateTime? dateTime) {
    if (dateTime == null) {
      return null;
    }
    return Timestamp.fromDate(dateTime);
  }
}

/// サーバー側で作成日時を設定するコンバータ。
///
/// 書き込み時は null の場合に [FieldValue.serverTimestamp] を使用し、
/// Firestore サーバーのタイムスタンプで記録する。
class ServerCreatedTimestamp implements JsonConverter<DateTime?, dynamic> {
  const ServerCreatedTimestamp();

  @override
  DateTime? fromJson(dynamic timestamp) {
    return timestamp?.toDate();
  }

  @override
  dynamic toJson(DateTime? dateTime) {
    if (dateTime == null) {
      return FieldValue.serverTimestamp();
    }
    return dateTime;
  }
}

/// サーバー側で更新日時を設定するコンバータ。
///
/// 書き込み時は常に [FieldValue.serverTimestamp] を使用し、
/// 書き込みのたびにサーバータイムスタンプで上書きする。
class ServerUpdatedTimestamp implements JsonConverter<DateTime?, dynamic> {
  const ServerUpdatedTimestamp();

  @override
  DateTime? fromJson(dynamic timestamp) {
    return timestamp?.toDate();
  }

  @override
  dynamic toJson(DateTime? date) {
    return FieldValue.serverTimestamp();
  }
}
