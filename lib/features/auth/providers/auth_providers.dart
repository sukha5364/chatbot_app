// 파일 경로: lib/features/auth/providers/auth_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/core/models/user_profile.dart';
import 'package:logging/logging.dart';

// --- 시나리오별 사용자 정보 하드코딩 ---
// (실제 앱에서는 안전한 방식으로 관리되어야 합니다)
final Map<String, UserProfile> _scenarioUsers = {
  "newrunner_01": const UserProfile(
      id: "newrunner_01", password: "pw_newrunner_01", name: "김민준", age: 28, gender: "남성",
      preferredSports: ["러닝"], otherInfo: "달리기 초보"
  ),
  "camping_master": const UserProfile(
      id: "camping_master", password: "pw_camping_master", name: "박선우", age: 35, gender: "남성",
      preferredSports: ["캠핑", "등산"], otherInfo: "캠핑 자주 다님, 장비 전문가 수준"
  ),
  "soccer_lover_7": const UserProfile(
      id: "soccer_lover_7", password: "pw_soccer_lover_7", name: "이강인", age: 23, gender: "남성",
      preferredSports: ["축구"], otherInfo: "프로 축구 선수 지망"
  ),
  "daily_active_user": const UserProfile(
      id: "daily_active_user", password: "pw_daily_active_user", name: "최수영", age: 31, gender: "여성",
      preferredSports: ["요가", "필라테스", "수영"], otherInfo: "거의 매일 운동"
  ),
  "family_shopper": const UserProfile(
      id: "family_shopper", password: "pw_family_shopper", name: "강하늘", age: 40, gender: "남성",
      preferredSports: ["자전거 타기", "주말 나들이"], otherInfo: "두 아이의 아빠, 가족용품 관심 많음"
  ),
};
// --- 시나리오별 사용자 정보 하드코딩 끝 ---


// 현재 로그인된 사용자 프로필 상태
final currentUserProfileProvider = StateProvider<UserProfile?>((ref) => null);

// 로그인 시도 중 로딩 상태
final authLoadingProvider = StateProvider<bool>((ref) => false);

// 로그인 로직을 담당하는 Notifier (비동기 작업 처리)
class AuthNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  final Ref ref; // <--- 수정됨: Reader -> Ref
  final _log = Logger('AuthNotifier');

  AuthNotifier(this.ref) : super(const AsyncValue.data(null)); // <--- 수정됨: 생성자 파라미터

  Future<bool> login(String userId, String password) async {
    state = const AsyncValue.loading();
    ref.read(authLoadingProvider.notifier).state = true; // <--- 수정됨: read -> ref.read
    _log.info("Attempting login for userId: $userId");

    try {
      // 실제 API 호출 대신 하드코딩된 사용자 정보와 비교
      await Future.delayed(const Duration(seconds: 1)); // 네트워크 지연 시뮬레이션

      if (_scenarioUsers.containsKey(userId)) {
        final userProfile = _scenarioUsers[userId]!;
        if (userProfile.password == password) {
          ref.read(currentUserProfileProvider.notifier).state = userProfile; // <--- 수정됨
          state = AsyncValue.data(userProfile);
          ref.read(authLoadingProvider.notifier).state = false; // <--- 수정됨
          _log.info("Login successful for userId: $userId, name: ${userProfile.name}");
          return true;
        } else {
          throw Exception("비밀번호가 일치하지 않습니다.");
        }
      } else {
        throw Exception("존재하지 않는 사용자 ID입니다.");
      }
    } catch (e, stackTrace) {
      _log.severe("Login failed for userId: $userId", e, stackTrace);
      state = AsyncValue.error(e, stackTrace);
      ref.read(authLoadingProvider.notifier).state = false; // <--- 수정됨
      ref.read(currentUserProfileProvider.notifier).state = null; // <--- 수정됨: 로그인 실패 시 프로필 null 처리
      return false;
    }
  }

  void logout() {
    _log.info("User logged out: ${ref.read(currentUserProfileProvider)?.id}"); // <--- 수정됨
    ref.read(currentUserProfileProvider.notifier).state = null; // <--- 수정됨
    state = const AsyncValue.data(null); // 로그인 상태도 초기화
  }
}

// AuthNotifier Provider
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<UserProfile?>>((ref) {
  return AuthNotifier(ref);
});