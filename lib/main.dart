import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'pages/main_scaffold.dart';
import 'pages/login_page.dart';
import 'pages/onboarding_page.dart';
import 'services/auth_service.dart';
import 'services/migration_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  await MigrationService.runMigrations();
  final onboardingDone = await OnboardingPage.isCompleted();
  runApp(MyApp(onboardingDone: onboardingDone));
}

class MyApp extends StatelessWidget {
  final bool onboardingDone;
  const MyApp({super.key, required this.onboardingDone});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '体調予測',
      theme: buildCalmBlueTheme(),
      home: AuthWrapper(onboardingDone: onboardingDone),
    );
  }
}

/// 認証状態に応じて OnboardingPage / LoginPage / MainScaffold を切り替え
class AuthWrapper extends StatefulWidget {
  final bool onboardingDone;
  const AuthWrapper({super.key, required this.onboardingDone});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late bool _onboardingDone;

  @override
  void initState() {
    super.initState();
    _onboardingDone = widget.onboardingDone;
  }

  @override
  Widget build(BuildContext context) {
    // 初回起動: プライバシーオンボーディング
    if (!_onboardingDone) {
      return OnboardingPage(
        onComplete: () {
          setState(() => _onboardingDone = true);
        },
      );
    }

    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const MainScaffold();
        }
        return const LoginPage();
      },
    );
  }
}
