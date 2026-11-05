import 'package:flutter_test/flutter_test.dart';
import 'package:smart_check/views/student/puerta_celular_screen.dart';

void main() {
  group('pasoAlEntrar', () {
    test('desde el celular vinculado entra directo', () {
      expect(
        pasoAlEntrar(
          vinculado: 'android-1',
          esteCelular: 'android-1',
          hayConQueComparar: true,
        ),
        PasoAlEntrar.entrar,
      );
    });

    test('desde otro celular tiene que confirmar su rostro', () {
      // Lo que pasaba antes: se registró en un teléfono, entró en otro y la
      // app lo dejó pasar como si nada.
      expect(
        pasoAlEntrar(
          vinculado: 'android-1',
          esteCelular: 'android-2',
          hayConQueComparar: true,
        ),
        PasoAlEntrar.cambiar,
      );
    });

    test('sin celular vinculado todavía, vincula este con su rostro', () {
      expect(
        pasoAlEntrar(
          vinculado: null,
          esteCelular: 'android-2',
          hayConQueComparar: true,
        ),
        PasoAlEntrar.vincular,
      );
      expect(
        pasoAlEntrar(
          vinculado: '',
          esteCelular: 'android-2',
          hayConQueComparar: true,
        ),
        PasoAlEntrar.vincular,
      );
    });

    test('sin foto en Chairá ni rostro guardado no hay con qué comparar', () {
      // No se le deja por fuera de ver su asistencia; marcar no puede sin
      // rostro, así que no gana nada.
      expect(
        pasoAlEntrar(
          vinculado: 'android-1',
          esteCelular: 'android-2',
          hayConQueComparar: false,
        ),
        PasoAlEntrar.entrar,
      );
    });

    test('donde el celular no da identificador no hay nada que atar', () {
      expect(
        pasoAlEntrar(
          vinculado: 'android-1',
          esteCelular: null,
          hayConQueComparar: true,
        ),
        PasoAlEntrar.entrar,
      );
    });
  });
}
