import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'services/auth_service.dart';
import 'services/task_service.dart';

// ── Auth Providers ────────────────────────────────────────────────
final authService = Provider((ref) => AuthService());

final authStateProvider = StateNotifierProvider<AuthNotifier, bool>((ref) {
  return AuthNotifier(ref.watch(authService));
});

class AuthNotifier extends StateNotifier<bool> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(false) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    state = await _authService.isUserSignedIn();
  }

  void setLoggedIn(bool loggedIn) {
    state = loggedIn;
  }
}

final currentUserProvider = FutureProvider<AuthUser?>((ref) async {
  final signedIn = ref.watch(authStateProvider);
  if (!signedIn) return null;
  return ref.watch(authService).getCurrentUser();
});

// ── Tasks & APIs Providers ────────────────────────────────────────
final taskService = Provider((ref) => TaskService());

final tasksProvider = FutureProvider<List<dynamic>>((ref) async {
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  
  // Use the cognito username/userId to fetch their specific tasks
  return ref.watch(taskService).fetchTasks(user.userId);
});
