import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

void main() async {
  // Flutter debe estar listo antes de usar plugins nativos como Firebase.
  WidgetsFlutterBinding.ensureInitialized();
  // Conecta la app con el proyecto de Firebase (datos en firebase_options).
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SmartCheckApp());
}

class SmartCheckApp extends StatelessWidget {
  const SmartCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Por ahora solo comprobamos que la app arranca conectada a Firebase.
    return const MaterialApp(
      title: 'SmartCheck',
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('SmartCheck'))),
    );
  }
}
