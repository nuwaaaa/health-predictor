import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showEmailForm = false;
  bool _isLogin = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 匿名認証
  // ---------------------------------------------------------------------------
  Future<void> _signInAnonymously() async {
    setState(() => _loading = true);
    try {
      await _authService.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      _showError(_authErrorMessage(e.code));
    } catch (e) {
      _showError('エラー: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // ソーシャルログイン
  // ---------------------------------------------------------------------------
  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      await _authService.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      _showError(_authErrorMessage(e.code));
    } catch (e) {
      _showError('エラー: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _loading = true);
    try {
      await _authService.signInWithApple();
    } on FirebaseAuthException catch (e) {
      _showError(_authErrorMessage(e.code));
    } catch (e) {
      _showError('エラー: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // メール/パスワード
  // ---------------------------------------------------------------------------
  Future<void> _submitEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('メールアドレスとパスワードを入力してください');
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isLogin) {
        await _authService.signIn(email: email, password: password);
      } else {
        await _authService.signUp(email: email, password: password);
      }
    } on FirebaseAuthException catch (e) {
      _showError(_authErrorMessage(e.code));
    } catch (e) {
      _showError('エラー: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'ユーザーが見つかりません';
      case 'wrong-password':
      case 'invalid-credential':
        return 'メールアドレスまたはパスワードが間違っています';
      case 'email-already-in-use':
        return 'このメールアドレスは既に使用されています';
      case 'weak-password':
        return 'パスワードが弱すぎます（6文字以上）';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません';
      default:
        return '認証エラーが発生しました';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '体調予測',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'あなた専用の体調予測AI',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 40),

                // --- メインCTA: アカウントなしで始める ---
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signInAnonymously,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading && !_showEmailForm
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('アカウントなしで始める',
                            style: TextStyle(fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 24),

                // --- 区切り線 ---
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('または',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),

                const SizedBox(height: 24),

                // --- Apple Sign-In (iOS のみ) ---
                if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                  _socialButton(
                    label: 'Appleでサインイン',
                    icon: Icons.apple,
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    onPressed: _loading ? null : _signInWithApple,
                  ),
                  const SizedBox(height: 12),
                ],

                // --- Google Sign-In ---
                _socialButton(
                  label: 'Googleでサインイン',
                  icon: Icons.g_mobiledata,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  borderColor: Colors.grey.shade300,
                  onPressed: _loading ? null : _signInWithGoogle,
                ),

                const SizedBox(height: 12),

                // --- メール/パスワード トグル ---
                TextButton(
                  onPressed: _loading
                      ? null
                      : () =>
                          setState(() => _showEmailForm = !_showEmailForm),
                  child: Text(
                    _showEmailForm ? '閉じる' : 'メールアドレスでサインイン',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),

                // --- メールフォーム ---
                if (_showEmailForm) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_loading,
                    decoration: InputDecoration(
                      labelText: 'メールアドレス',
                      hintText: 'example@email.com',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    enabled: !_loading,
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      hintText: '6文字以上',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submitEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _isLogin ? 'ログイン' : '登録する',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin
                          ? 'アカウントをお持ちでない方はこちら'
                          : '既にアカウントをお持ちの方はこちら',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color foregroundColor,
    Color? borderColor,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24, color: foregroundColor),
        label: Text(label,
            style: TextStyle(fontSize: 15, color: foregroundColor)),
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor ?? backgroundColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
