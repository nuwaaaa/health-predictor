import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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
  // Google Sign-In
  // ---------------------------------------------------------------------------

  /// Google Sign-In の credential を取得
  Future<OAuthCredential?> _getGoogleCredential() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // ユーザーがキャンセル

    final googleAuth = await googleUser.authentication;
    return GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
  }

  /// Google でログイン
  Future<UserCredential?> signInWithGoogle() async {
    final credential = await _getGoogleCredential();
    if (credential == null) return null;
    return _auth.signInWithCredential(credential);
  }

  /// 匿名アカウントに Google を連携（uid維持）
  Future<UserCredential?> linkWithGoogle() async {
    final credential = await _getGoogleCredential();
    if (credential == null) return null;
    return _auth.currentUser!.linkWithCredential(credential);
  }

  // ---------------------------------------------------------------------------
  // Apple Sign-In
  // ---------------------------------------------------------------------------

  /// Apple Sign-In 用の nonce 生成
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Apple でログイン
  Future<UserCredential?> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    return _auth.signInWithCredential(oauthCredential);
  }

  /// 匿名アカウントに Apple を連携（uid維持）
  Future<UserCredential?> linkWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    return _auth.currentUser!.linkWithCredential(oauthCredential);
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
    final credential = await _getGoogleCredential();
    if (credential == null) throw Exception('Google再認証がキャンセルされました');
    await _auth.currentUser!.reauthenticateWithCredential(credential);
  }

  /// Apple で再認証
  Future<void> reauthenticateWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [],
      nonce: nonce,
    );

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    await _auth.currentUser!.reauthenticateWithCredential(oauthCredential);
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
