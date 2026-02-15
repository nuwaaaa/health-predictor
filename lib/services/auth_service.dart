import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 認証状態の変化を監視するストリーム
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 現在のユーザー
  User? get currentUser => _auth.currentUser;

  /// 現在のUID（未ログイン時はnull）
  String? get uid => _auth.currentUser?.uid;

  /// メール/パスワードでログイン
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// メール/パスワードで新規登録
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// ログアウト
  Future<void> signOut() => _auth.signOut();
}
