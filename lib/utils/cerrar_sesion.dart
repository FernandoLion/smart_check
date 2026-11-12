import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/student_viewmodel.dart';
import '../viewmodels/teacher_viewmodel.dart';

/// Cierra la sesión. Primero apaga las escuchas de cursos del portal: con la
/// sesión ya cerrada, Firestore les negaría el permiso y ese error quedaría
/// pintado al volver a entrar.
Future<void> cerrarSesion(BuildContext context) async {
  final auth = context.read<AuthViewModel>();
  context.read<StudentViewModel>().dejarDeVigilar();
  context.read<TeacherViewModel>().dejarDeVigilar();
  await auth.signOut();
}
