import 'package:amplify_flutter/amplify_flutter.dart';

class AuthService {
  Future<bool> isUserSignedIn() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      return session.isSignedIn;
    } on AuthException catch (e) {
      safePrint('Error fetching auth session: ${e.message}');
      return false;
    }
  }

  Future<AuthUser?> getCurrentUser() async {
    try {
      if (await isUserSignedIn()) {
        return await Amplify.Auth.getCurrentUser();
      }
      return null;
    } on AuthException catch (e) {
      safePrint('Error getting current user: ${e.message}');
      return null;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      final result = await Amplify.Auth.signInWithWebUI(
        provider: AuthProvider.google,
      );
      safePrint('Sign in result: $result');
      return result.isSignedIn;
    } on AuthException catch (e) {
      safePrint('Error signing in: ${e.message}');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
      safePrint('Signed out successfully');
    } on AuthException catch (e) {
      safePrint('Error signing out: ${e.message}');
    }
  }
}
