import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'utils/app_theme.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'views/login_screen.dart';

void main() async {
  // Flutter debe estar listo antes de usar plugins nativos como Firebase.
  WidgetsFlutterBinding.ensureInitialized();
  // La app se usa con el celular en vertical.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Conecta la app con el proyecto de Firebase (datos en firebase_options).
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SmartCheckApp());
}

class SmartCheckApp extends StatelessWidget {
  const SmartCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    // El Provider crea UN AuthViewModel y lo deja disponible para todas las
    // pantallas que estén debajo (login y home comparten el mismo).
    return ChangeNotifierProvider(
      create: (_) => AuthViewModel(),
      child: MaterialApp(
        title: 'SmartCheck',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const LoginScreen(),
      ),
    );
  }
}
