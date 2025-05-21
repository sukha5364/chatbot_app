// 파일 경로: lib/core/models/user_profile.dart
// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id, // 예: newrunner_01
    required String password, // 데모용 로그인 확인용 (실제 앱에서는 사용하지 않음)
    required String name, // 예: 김민준
    required int age,
    required String gender, // "남성", "여성"
    @Default([]) List<String> preferredSports,
    String? otherInfo,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}