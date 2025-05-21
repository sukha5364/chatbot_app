// 파일 경로: lib/features/auth/presentation/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:decathlon_demo_app/features/auth/providers/auth_providers.dart';
import 'package:decathlon_demo_app/features/chat/presentation/chat_screen.dart';
import 'package:decathlon_demo_app/core/models/user_profile.dart'; // ⬅️ UserProfile 모델 import 추가
import 'package:logging/logging.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _log = Logger('LoginScreen');
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();

  final List<Map<String, String>> _demoUsers = [
    {"id": "newrunner_01", "pw": "pw_newrunner_01", "desc": "S1: 신규 러너"},
    {"id": "camping_master", "pw": "pw_camping_master", "desc": "S2: 기존 캠퍼"},
    {"id": "soccer_lover_7", "pw": "pw_soccer_lover_7", "desc": "S3: 축구 용품"},
    {"id": "daily_active_user", "pw": "pw_daily_active_user", "desc": "S4: 매장 활동"},
    {"id": "family_shopper", "pw": "pw_family_shopper", "desc": "S5: 가족 쇼핑"},
  ];
  String? _selectedDemoUser;

  @override
  void dispose() {
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _performLogin() async {
    if (_formKey.currentState!.validate()) {
      final userId = _userIdController.text.trim();
      final password = _passwordController.text.trim();
      _log.info("Login button pressed for userId: $userId");

      final success = await ref.read(authNotifierProvider.notifier).login(userId, password);

      if (success && mounted) {
        _log.info("Navigating to ChatScreen for user: $userId");
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ChatScreen()),
        );
      }
    } else {
      _log.warning("Login form validation failed.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);
    final authState = ref.watch(authNotifierProvider);

    // UserProfile? 타입을 명시적으로 사용합니다.
    ref.listen<AsyncValue<UserProfile?>>(authNotifierProvider, (_, next) {
      if (next is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('로그인 실패: ${next.error.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(
                  Icons.sports_soccer,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  '데카트론 AI 챗봇 시연',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 32),

                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: '시나리오 사용자 선택 (시연용)'),
                  value: _selectedDemoUser,
                  items: _demoUsers.map((user) {
                    return DropdownMenuItem<String>(
                      value: user['id'],
                      child: Text(user['desc']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      final selected = _demoUsers.firstWhere((u) => u['id'] == value);
                      _userIdController.text = selected['id']!;
                      _passwordController.text = selected['pw']!;
                      setState(() {
                        _selectedDemoUser = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _userIdController,
                  decoration: const InputDecoration(
                    labelText: '사용자 ID',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  keyboardType: TextInputType.text,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '사용자 ID를 입력해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '비밀번호를 입력해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: isLoading ? null : _performLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text('로그인', style: Theme.of(context).textTheme.labelLarge),
                ),
                if (authState is AsyncError && !isLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      '오류: ${authState.error.toString().replaceFirst("Exception: ", "")}',
                      style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}