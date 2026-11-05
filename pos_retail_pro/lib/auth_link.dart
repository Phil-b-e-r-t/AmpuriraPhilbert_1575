import 'package:firebase_auth/firebase_auth.dart';
import 'state.dart';

/// Lets someone who signed in with Google also sign in with their email and a password.
extension EmailPasswordLink on AppState {
  /// True when the signed-in account already has an email + password login.
  /// (Also true when it cannot be determined, so the normal "Change password" flow is kept.)
  bool get hasPasswordLogin {
    if (firebaseAuthError != null) return true;
    final user = FirebaseAuth.instance.currentUser;
    return user == null || user.providerData.any((p) => p.providerId == 'password');
  }

  /// Adds an email/password login to the current (Google) account.
  /// Returns null on success, or an error message to show.
  Future<String?> setEmailPassword(String password) async {
    if (firebaseAuthError != null) return firebaseAuthError;
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;
    if (user == null || email == null || email.isEmpty) return 'Sign in again to continue.';
    if (password.length < 8) return 'Password must be at least 8 characters';
    try {
      await user.linkWithCredential(EmailAuthProvider.credential(email: email, password: password));
      await user.reload();
      return null;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'requires-recent-login' => 'For security, log out and continue with Google again, then set your password.',
        'weak-password' => 'Choose a stronger password.',
        'provider-already-linked' || 'email-already-in-use' || 'credential-already-in-use' =>
          'This account already has an email password.',
        'network-request-failed' => 'Connect to the internet to set your password.',
        _ => e.message ?? 'Could not set the password (${e.code}).',
      };
    }
  }
}
