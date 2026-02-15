import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 認証状態の変化を監視するストリーム
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// 現在のユーザー
  User? get currentUser => _auth.currentUser;

  /// 現在のUID（未ログイン時はnull）
  String? get uid => _auth.currentUser?.uid;

  /// 匿名ユーザーかどうか
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  // ---------------------------------------------------------------------------
  // 匿名認証
  // ---------------------------------------------------------------------------

  /// 匿名認証でログイン
  Future<UserCredential> signInAnonymously() {
    return _auth.signInAnonymously();
  }

  // ---------------------------------------------------------------------------
  // メール/パスワード
  // ---------------------------------------------------------------------------

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

  /// 匿名アカウントにメール/パスワードを連携（uid維持）
  Future<UserCredential> linkWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    return _auth.currentUser!.linkWithCredential(credential);
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In（Firebase signInWithProvider）
  // ---------------------------------------------------------------------------

  /// Google でログイン
  Future<UserCredential> signInWithGoogle() {
    return _auth.signInWithProvider(GoogleAuthProvider());
  }

  /// 匿名アカウントに Google を連携（uid維持）
  Future<UserCredential> linkWithGoogle() {
    return _auth.currentUser!.linkWithProvider(GoogleAuthProvider());
  }

  // ---------------------------------------------------------------------------
  // Apple Sign-In（Firebase signInWithProvider）
  // ---------------------------------------------------------------------------

  /// Apple でログイン
  Future<UserCredential> signInWithApple() {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    return _auth.signInWithProvider(provider);
  }

  /// 匿名アカウントに Apple を連携（uid維持）
  Future<UserCredential> linkWithApple() {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    return _auth.currentUser!.linkWithProvider(provider);
  }

  // ---------------------------------------------------------------------------
  // 再認証
  // ---------------------------------------------------------------------------

  /// メール/パスワードで再認証
  Future<void> reauthenticateWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await _auth.currentUser!.reauthenticateWithCredential(credential);
  }

  /// Google で再認証
  Future<void> reauthenticateWithGoogle() async {
    await _auth.currentUser!.reauthenticateWithProvider(GoogleAuthProvider());
  }

  /// Apple で再認証
  Future<void> reauthenticateWithApple() async {
    await _auth.currentUser!.reauthenticateWithProvider(AppleAuthProvider());
  }

  // ---------------------------------------------------------------------------
  // アカウント削除
  // ---------------------------------------------------------------------------

  /// Firebase Auth のアカウントを削除
  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
  }

  /// 連携済みプロバイダー一覧を取得
  List<String> get linkedProviders {
    return _auth.currentUser?.providerData
            .map((info) => info.providerId)
            .toList() ??
        [];
  }

  // ---------------------------------------------------------------------------
  // ログアウト
  // ---------------------------------------------------------------------------

  /// ログアウト
  Future<void> signOut() => _auth.signOut();
}
