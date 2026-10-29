import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'utils/app_theme.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'views/login_screen.dart';
import 'viewmodels/student_viewmodel.dart';
import 'viewmodels/teacher_viewmodel.dart';

/// Para probar sin tocar el Firebase real:
/// `firebase emulators:start` y luego
/// `flutter run --dart-define=USE_FIREBASE_EMULATOR=true`.
const _usarEmuladorFirebase = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // El radar y la baliza se usan con el celular en la mano: nada de girar.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (_usarEmuladorFirebase) {
    // 10.0.2.2 es el "localhost" del PC visto desde el emulador de Android.
    const host = String.fromEnvironment(
      'FIREBASE_EMULATOR_HOST',
      defaultValue: '10.0.2.2',
    );
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  }
  runApp(const SmartCheckApp());
}

class SmartCheckApp extends StatelessWidget {
  const SmartCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => StudentViewModel()),
        ChangeNotifierProvider(create: (_) => TeacherViewModel()),
      ],
      child: MaterialApp(
        title: 'SmartCheck',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const LoginScreen(),
      ),
    );
  }
}
