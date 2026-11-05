# SmartCheck: el login explicado paso a paso

Esta rama (`login-sustentacion`) tiene **solo el inicio de sesión** de SmartCheck. Se armó desde cero y en orden: cada commit es un paso de esta explicación. Para seguirla en vivo:

```bash
git log --oneline --reverse
```

| Commit | Qué agrega |
|---|---|
| paso 1 | Proyecto Flutter base conectado a Firebase |
| paso 2 | Modelo del perfil y servicios de Firebase |
| paso 3 | ViewModel del inicio de sesión |
| paso 4 | Pantalla de login y pantalla de inicio |
| paso 5 | Pruebas del login |

---

## 0. La idea general

### Qué hace el login

1. La persona escribe su usuario institucional (`an.perez`) y su contraseña. El `@udla.edu.co` ya viene puesto.
2. **Firebase Authentication** comprueba que el correo y la contraseña sean correctos.
3. Con la sesión abierta, la app lee el **perfil** de la persona en **Cloud Firestore** (`usuarios/{uid}`). Ahí está su nombre y sus **roles** (`docente`, `estudiante` o los dos).
4. Según el rol, entra como docente, como estudiante o, si tiene los dos, se le pregunta con cuál quiere entrar.
5. Si la persona ya había entrado en ese celular, la próxima vez entra directo sin escribir la contraseña (**sesión guardada**).

### Por qué hacen falta dos servicios de Firebase

- **Firebase Auth** solo sabe *correo + contraseña*. Responde "sí, esta persona es quien dice ser" y le da un identificador único, el **uid**.
- **Firestore** es la base de datos. Ahí guardamos lo que Auth no sabe: el nombre y si es docente o estudiante. El documento se busca con el mismo uid.

```
Firebase Auth                     Firestore
┌─────────────────────────┐       ┌───────────────────────────────────┐
│ an.perez@udla.edu.co    │       │ usuarios/                         │
│ contraseña (cifrada)    │──uid─▶│   abc123  ← el uid de Auth        │
│ uid: abc123             │       │     email:  "an.perez@udla.edu.co"│
└─────────────────────────┘       │     nombre: "ANA MARÍA PÉREZ"     │
                                  │     roles:  ["estudiante"]        │
                                  └───────────────────────────────────┘
```

### La arquitectura: MVVM

El código está separado en capas. Cada una tiene un solo trabajo:

```
┌──────────────────────┐   lee el estado / llama métodos   ┌────────────────────┐
│  VISTA (View)        │ ────────────────────────────────▶ │  VIEWMODEL         │
│  login_screen.dart   │                                   │  auth_viewmodel    │
│  home_screen.dart    │ ◀──────────────────────────────── │                    │
│  Dibuja y reacciona  │      notifyListeners()            │  Lógica y estado   │
└──────────────────────┘      ("cambié, redibújate")       └─────────┬──────────┘
                                                                     │ usa
                                                       ┌─────────────▼───────────────┐
                                                       │  SERVICIOS                  │
                                                       │  auth_service   → Auth      │
                                                       │  perfil_service → Firestore │
                                                       └─────────────┬───────────────┘
                                                                     │ devuelve
                                                       ┌─────────────▼───────────────┐
                                                       │  MODELO                     │
                                                       │  usuario_perfil_model       │
                                                       └─────────────────────────────┘
```

- **Modelo**: los datos (quién es el usuario y sus roles).
- **Servicios**: los únicos que hablan con Firebase.
- **ViewModel**: la lógica. Valida, decide y guarda el estado (si está cargando, el error, el perfil).
- **Vista**: solo dibuja lo que dice el ViewModel y le pasa lo que toca el usuario.

**¿Por qué así?** La pantalla no sabe nada de Firebase y el ViewModel no sabe nada de botones. Eso permite **probar la lógica sin Firebase** (paso 5) y cambiar el diseño sin tocar la lógica.

### Los archivos

```
lib/
├── main.dart                       ← arranca la app (pasos 1 y 4)
├── firebase_options.dart           ← datos de conexión a Firebase (paso 1)
├── models/
│   └── usuario_perfil_model.dart   ← Modelo (paso 2)
├── services/
│   ├── auth_service.dart           ← Firebase Auth (paso 2)
│   └── perfil_service.dart         ← Firestore (paso 2)
├── viewmodels/
│   └── auth_viewmodel.dart         ← ViewModel (paso 3)
├── utils/
│   ├── usuario_input_formatter.dart← limpia lo que se escribe en "usuario" (paso 3)
│   └── app_theme.dart              ← colores y estilos (paso 4)
└── views/
    ├── login_screen.dart           ← Vista del login (paso 4)
    └── home_screen.dart            ← Vista de llegada (paso 4)
test/                               ← pruebas (paso 5)
```

---

## Paso 1: proyecto base conectado a Firebase

### `pubspec.yaml`: las dependencias

Es la "lista de compras" del proyecto. Solo hay cuatro paquetes:

| Paquete | Para qué |
|---|---|
| `firebase_core` | Conectar la app con el proyecto de Firebase. Los otros dos lo necesitan. |
| `firebase_auth` | Iniciar y cerrar sesión con correo y contraseña. |
| `cloud_firestore` | Leer el perfil (nombre y roles) en la base de datos. |
| `provider` | Pasarle el ViewModel a las pantallas y redibujarlas cuando cambia. |

En `dev_dependencies` están `flutter_test` (para las pruebas) y `flutter_lints` (reglas de estilo que revisa `flutter analyze`).

### `android/`: la parte de Android

Flutter genera esta carpeta. Lo importante para el login:

- **`android/app/google-services.json`**: lo descarga Firebase y le dice a Android a qué proyecto conectarse (`smart-check-8bd33`).
- **`android/settings.gradle.kts`** y **`android/app/build.gradle.kts`**: activan el plugin `com.google.gms.google-services`, que lee ese JSON al compilar.
- **`AndroidManifest.xml`**: solo pide el permiso `INTERNET`, porque el login habla con Firebase por la red.
- **`MainActivity.kt`**: la actividad de Android que muestra la app. No hace nada especial.

### `lib/firebase_options.dart`

Lo genera la herramienta **FlutterFire CLI** (`flutterfire configure`). Tiene la `apiKey`, el `appId` y el `projectId` del proyecto de Firebase. `DefaultFirebaseOptions.currentPlatform` devuelve los datos de Android. Las otras plataformas lanzan un error porque no se configuraron.

> **Pregunta típica:** "¿No es peligroso que la `apiKey` esté en el código?" No. Esa clave solo **identifica** el proyecto y no da permisos. Lo que protege los datos son las **reglas de seguridad** de Firestore y la autenticación.

### `lib/main.dart` (versión del paso 1)

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SmartCheckApp());
}
```

- **`main`** es lo primero que se ejecuta.
- **`WidgetsFlutterBinding.ensureInitialized()`**: Firebase es un plugin nativo, y Flutter tiene que estar listo antes de hablar con Android. Sin esta línea, `initializeApp` falla.
- **`await Firebase.initializeApp(...)`**: conecta con Firebase. El `await` espera a que termine antes de seguir.
- **`runApp(...)`**: dibuja el primer widget.

En este paso la app solo muestra el texto "SmartCheck". Sirve para comprobar que arranca conectada.

---

## Paso 2: modelo y servicios

### `models/usuario_perfil_model.dart`: el Modelo

```dart
class Rol {
  static const docente = 'docente';
  static const estudiante = 'estudiante';
}
```

Las constantes evitan escribir `'docente'` a mano en muchos lugares, donde un error de tipeo pasaría sin que nadie lo note.

```dart
class UsuarioPerfil {
  final String uid;
  final String email;
  final String nombre;
  final List<String> roles;
  ...
}
```

- Todos los campos son **`final`**: un perfil no cambia después de creado.
- **`factory UsuarioPerfil.fromMap(uid, map)`** convierte el documento de Firestore (un `Map` de clave → valor) en un objeto de Dart. Usa `as String? ?? ''` para que, si falta un campo, quede vacío y la app no se caiga.
- Tiene tres **getters** que el resto del código usa para decidir:
  - `esDocente`: si sus roles incluyen `docente`.
  - `esEstudiante`: si incluyen `estudiante`.
  - `esDual`: si es las dos cosas. Es el único caso en que se pregunta con qué perfil entrar.

### `services/auth_service.dart`: Firebase Auth

Es la **única** clase que usa `FirebaseAuth`. Si mañana se cambia de proveedor, solo cambia este archivo.

```dart
FirebaseAuth get _auth => FirebaseAuth.instance;
```
Es un *getter* y no una variable para que `FirebaseAuth.instance` se pida **al usarse**. Así se puede crear el servicio en las pruebas aunque Firebase no esté inicializado.

**`signInWithEmailPassword(email, password)`**
- Llama a `_auth.signInWithEmailAndPassword(...)`.
- Devuelve **`null` si salió bien**, o un **mensaje de error en español** si falló.
- Firebase responde con códigos en inglés (`invalid-credential`, `too-many-requests`, `network-request-failed`…). Aquí cada código se traduce a un mensaje entendible para el usuario.
- `invalid-credential`: Firebase tiene una protección que **no dice si el usuario existe o no**, para que nadie pueda adivinar qué correos están registrados. Por eso el mensaje es "Usuario o contraseña incorrectos".

**`sesionGuardada()`**
- Firebase guarda la sesión en el celular. Al abrir la app la carga **en segundo plano**, así que `currentUser` puede estar en `null` unos milisegundos aunque sí haya sesión.
- Por eso se espera el **primer aviso** de `authStateChanges()`, con un máximo de 5 segundos (`timeout`).

**`signOut()`**: cierra la sesión en Firebase.

### `services/perfil_service.dart`: Firestore

```dart
CollectionReference<Map<String, dynamic>> get _usuarios =>
    FirebaseFirestore.instance.collection('usuarios');
```

**`obtener(uid)`**
1. Lee el documento `usuarios/{uid}` con `.get()`.
2. Si Firestore no responde en 15 segundos, se rinde (`.timeout(_timeout)`). Así la app no se queda cargando para siempre.
3. Si el documento no existe devuelve `null`; si existe, lo convierte con `UsuarioPerfil.fromMap`.
4. Si algo falla, lanza una **`PerfilException`** con un mensaje claro (sin conexión, permiso denegado, no respondió a tiempo).

**¿Por qué una excepción propia?** El ViewModel solo tiene que atrapar `PerfilException` y mostrar `e.mensaje`. No necesita conocer los errores internos de Firestore.

---

## Paso 3: el ViewModel

### `utils/usuario_input_formatter.dart`

- **`dominioInstitucional = '@udla.edu.co'`**: el único dominio permitido.
- **`formatoUsuario`**: una expresión regular que dice qué es un usuario válido: letras y números, con puntos, guiones o guiones bajos **entre** ellos.
  - Válidos: `an.perez`, `wi.patino-2`.
  - Inválidos: `an perez` (espacio), `an..perez` (dos puntos seguidos), `.an` (empieza con punto).
- **`UsuarioInstitucionalFormatter`**: un `TextInputFormatter` que corrige el texto **mientras se escribe**:
  - lo pasa a minúsculas y le quita los espacios;
  - si la persona pega `an.perez@udla.edu.co`, deja solo `an.perez`, porque el dominio ya se muestra al lado;
  - si escribe otro dominio (`@gmail.com`), lo deja para que la validación lo rechace con un mensaje.

### `viewmodels/auth_viewmodel.dart`

```dart
class AuthViewModel extends ChangeNotifier { ... }
```

**`ChangeNotifier`** es la clave de MVVM en Flutter. Cuando el ViewModel cambia algo, llama a **`notifyListeners()`** y todas las pantallas que lo escuchan se redibujan solas.

**Constructor con servicios opcionales**
```dart
AuthViewModel({AuthService? authService, PerfilService? perfilService})
  : _authService = authService ?? AuthService(),
    _perfilService = perfilService ?? PerfilService();
```
En la app real se crean los servicios de Firebase. En las pruebas se pasan **servicios falsos**. Esto se llama **inyección de dependencias**.

**Estado privado y getters públicos**
```dart
bool _isLoading = false;     // ¿se está intentando entrar?
String? _errorMessage;       // el último error, para mostrarlo
UsuarioPerfil? _perfil;      // quién entró (null = nadie)

bool get isLoading => _isLoading;
```
El `_` hace que la variable sea privada. La pantalla puede **leer** el estado pero no **cambiarlo**: solo el ViewModel lo cambia.

**Validación del usuario** (`static`, porque no dependen del estado)
- `errorUsuario(entrada)`: devuelve el motivo por el que el usuario no es válido, o `null` si está bien. Revisa tres cosas, en orden: que no esté vacío, que no sea de otro dominio y que cumpla `formatoUsuario`.
- `correoInstitucional(entrada)`: si es válido, devuelve el correo completo (`an.perez` → `an.perez@udla.edu.co`).

**`signIn(usuario, password)`**: el corazón del login, en cinco pasos:

```dart
// 1. Avisar que empezó la carga (la pantalla muestra el spinner).
_isLoading = true; _errorMessage = null; _perfil = null;
notifyListeners();

// 2. Validar el usuario ANTES de llamar a Firebase.
final correo = correoInstitucional(usuario);
if (correo == null) return _fallar(errorUsuario(usuario)!);

// 3. Firebase Auth comprueba correo y contraseña.
final error = await _authService.signInWithEmailPassword(correo, password);
if (error != null) return _fallar(error);

// 4. Leer el perfil en Firestore para saber el rol.
//    Sin perfil, o si falla, se cierra la sesión: no queda a medias.
final perfil = await _perfilService.obtener(_authService.currentUser!.uid);
if (perfil == null) { await _authService.signOut(); return _fallar(...); }

// 5. Éxito: quitar el spinner.
_isLoading = false;
notifyListeners();
return true;
```

- Devuelve `true` o `false`. Si es `false`, el motivo queda en `errorMessage`.
- **`_fallar(mensaje)`**: guarda el error, quita el spinner, avisa a la pantalla y devuelve `false`. Se reutiliza en cada salida con error.
- **¿Por qué se cierra la sesión si no hay perfil?** Sin perfil no se sabe si es docente o estudiante. Es más seguro no dejar entrar a medias.

**`restaurarSesion()`**: pregunta a `sesionGuardada()` si hay alguien. Si lo hay, carga su perfil. Si algo falla devuelve `false` y la pantalla pide el ingreso como siempre.

**`signOut()`**: cierra la sesión en Firebase, borra el perfil de memoria y avisa a la pantalla.

---

## Paso 4: las pantallas

### `main.dart` (versión final)

```dart
return ChangeNotifierProvider(
  create: (_) => AuthViewModel(),
  child: MaterialApp(
    theme: AppTheme.darkTheme,
    home: const LoginScreen(),
  ),
);
```

- **`ChangeNotifierProvider`** crea **un solo** `AuthViewModel` y lo pone "encima" de toda la app. Cualquier pantalla de abajo puede pedirlo, y el login y el home comparten el mismo, con el mismo perfil.
- **`MaterialApp`**: la app con su tema oscuro y `LoginScreen` como pantalla inicial.
- `SystemChrome.setPreferredOrientations([portraitUp])`: la app solo se usa en vertical.

### `utils/app_theme.dart`

Los colores de la app (`primary` índigo, `success` verde, `error` rojo…) y el `ThemeData` oscuro. Están en un solo lugar para no repetir códigos de color en cada pantalla.

### `views/login_screen.dart`

**¿Por qué `StatefulWidget`?** La pantalla tiene estado propio que no le importa al resto de la app: el texto de los campos (`TextEditingController`), si la contraseña se ve o no (`_obscurePassword`) y si todavía se está buscando la sesión guardada (`_restaurando`).

**Ciclo de vida**
- **`initState`**: se ejecuta una vez al crear la pantalla. Usa `addPostFrameCallback` para llamar a `_restaurar()` **después del primer dibujo**, porque antes el `context` todavía no puede usar Provider.
- **`_restaurar()`**: si `restaurarSesion()` devuelve `true`, entra directo según el rol. Si no, muestra el formulario.
- **`dispose`**: libera los controladores de texto al cerrar la pantalla. Si no se liberan, quedan ocupando memoria.

**`build`: cómo se dibuja**
- `context.watch<AuthViewModel>()`: **escucha** el ViewModel. Cada vez que este llama `notifyListeners()`, la pantalla se redibuja.
- Si `_restaurando` es `true`, solo muestra un círculo de carga.
- Si no: un `Stack` con el brillo de fondo y, encima, el logo (`_buildHeaderBranding`) y el formulario (`_buildLoginForm`).

**El formulario (`_buildLoginForm`)**
- **Campo usuario**: `inputFormatters: [UsuarioInstitucionalFormatter()]` limpia lo que se escribe, y `suffixIcon: _DominioFijo()` muestra la etiqueta `@udla.edu.co` a la derecha.
- **Campo contraseña**: `obscureText` oculta los caracteres. El ícono del ojo cambia `_obscurePassword` con `setState`, que redibuja solo esta pantalla.
- **Botón "Iniciar Sesión"**: `onPressed: isLoading ? null : _handleLoginSubmit`. Mientras carga, `onPressed` es `null`, el botón **se deshabilita** y muestra un spinner. Así no se envía el login dos veces.

**`_handleLoginSubmit()`: lo que pasa al tocar el botón**
1. Si algún campo está vacío, muestra "Por favor, ingresa tus datos de acceso." y no sigue.
2. `context.read<AuthViewModel>()` (**read**, no watch: aquí solo se llama un método, no hace falta escuchar) → `signIn(...)`.
3. `if (!mounted) return;`: mientras se esperaba a Firebase la pantalla pudo cerrarse. Usar el `context` de una pantalla cerrada da error.
4. Si falló, muestra `errorMessage` en un `SnackBar` rojo.
5. Si salió bien, llama a `_entrarSegunRol(perfil)`.

**`_entrarSegunRol(perfil)`**: el rol sale **del perfil guardado en Firestore**, no de un botón que elija el usuario. Así nadie entra como docente si no lo es.
- Si es dual: muestra la hoja para elegir perfil (`_showRoleSelectionSheet`).
- Si es solo docente: entra como docente.
- Si es solo estudiante: entra como estudiante.
- Si no tiene rol: cierra la sesión y muestra un error.

**`_showRoleSelectionSheet()`**: un `showModalBottomSheet` (hoja que sube desde abajo) con dos tarjetas `_OpcionRol` (Docente / Estudiante) y un botón "Cancelar" que cierra la sesión.

**`_navegarComo(rol)`**: muestra "Sesión Iniciada como …" y usa **`Navigator.pushReplacement`** para ir al `HomeScreen`. *Replacement* reemplaza el login en vez de apilarse encima: con el botón "atrás" no se vuelve al login.

**Widgets auxiliares**
- `_DominioFijo`: la etiqueta gris `@udla.edu.co` dentro del campo.
- `_OpcionRol`: una tarjeta de la hoja de elegir perfil. Se escribió una sola vez y se usa dos veces, cambiando el ícono, el color y los textos.

### `views/home_screen.dart`

Es la pantalla de llegada. En la app completa aquí van los paneles de docente y estudiante; para la sustentación basta con mostrar:
- "Bienvenido, docente/estudiante", el nombre y el correo, leídos del ViewModel con `watch`.
- **Cerrar sesión**: llama a `signOut()` y vuelve al login con `pushReplacement`. Se revisa `context.mounted` después del `await` por la misma razón que en el login.

---

## El recorrido completo de un login

```
Usuario escribe "an.perez" + contraseña y toca "Iniciar Sesión"
   │
   ▼
LoginScreen._handleLoginSubmit()        ¿campos vacíos? → SnackBar y fin
   │
   ▼
AuthViewModel.signIn()
   ├─ isLoading = true → notifyListeners()   (el botón muestra el spinner)
   ├─ correoInstitucional("an.perez") → "an.perez@udla.edu.co"
   │                                       ¿inválido? → _fallar(...)
   ├─ AuthService.signInWithEmailPassword()  ──▶ Firebase Auth
   │                                       ¿error? → _fallar(mensaje en español)
   ├─ PerfilService.obtener(uid)             ──▶ Firestore usuarios/{uid}
   │                                       ¿sin perfil o falla? → signOut + _fallar
   └─ isLoading = false → notifyListeners() → return true
   │
   ▼
LoginScreen._entrarSegunRol(perfil)
   ├─ dual        → hoja "¿Con qué perfil…?" → elige
   ├─ docente     → HomeScreen(rol: docente)
   └─ estudiante  → HomeScreen(rol: estudiante)
```

La próxima vez que abra la app, `initState` → `_restaurar()` → `restaurarSesion()` encuentra la sesión guardada y entra directo, sin pasar por el formulario.

---

## Paso 5: las pruebas

```bash
flutter test
```

Son **22 pruebas** y ninguna toca el Firebase real.

- **`test/auth_fakes.dart`**: servicios **falsos** en memoria. `FakeAuthService` guarda las cuentas en un mapa (correo → contraseña) y `FakePerfilService` guarda los perfiles en otro mapa (uid → perfil). Se le pasan al ViewModel por el constructor: esa es la ventaja de la inyección de dependencias del paso 3.
- **`test/usuario_input_formatter_test.dart`**: el campo de usuario deja solo `an.perez` aunque se pegue el correo completo o se escriba en mayúsculas.
- **`test/auth_viewmodel_test.dart`**: la lógica:
  - carga el perfil y los roles;
  - rechaza una contraseña incorrecta;
  - cierra la sesión si no puede leer el perfil o si la cuenta no tiene perfil;
  - cerrar sesión borra el perfil;
  - restaura la sesión guardada;
  - acepta solo usuarios `@udla.edu.co` bien escritos, y **no llama a Firebase** si el usuario es inválido.
- **`test/login_screen_test.dart`**: la pantalla de verdad, tocando botones:
  - el estudiante entra directo;
  - el docente entra directo;
  - al docente que también estudia se le pregunta con qué perfil entrar;
  - con la sesión guardada entra sin el formulario;
  - "Cerrar sesión" vuelve al login.

---

## Cómo correrlo

```bash
flutter pub get
```

```bash
flutter run
```

Hace falta un celular o emulador Android: Firebase solo está configurado para Android. Para entrar se necesita una cuenta que exista en Firebase Auth **y** que tenga su documento en `usuarios/{uid}` con `nombre` y `roles`. Las cuentas creadas con la app completa ya lo tienen.

---

## Preguntas que pueden hacer en la sustentación

**¿Dónde se guarda la contraseña?**
En Firebase Authentication, cifrada. La app nunca la guarda ni la ve después de enviarla.

**¿Cómo sabe la app si soy docente o estudiante?**
Por el campo `roles` del documento `usuarios/{uid}` en Firestore. No lo elige el usuario en la pantalla.

**¿Qué pasa si no hay internet?**
Firebase responde `network-request-failed` y se muestra "Sin conexión. Revisa tu internet…". Si es Firestore el que no responde, a los 15 segundos se muestra "el servidor no respondió a tiempo".

**¿Por qué MVVM y Provider?**
Para separar lo que se ve de la lógica. Así la lógica se prueba sin pantalla y sin Firebase, y la pantalla se puede rediseñar sin tocar la lógica. Provider es la forma recomendada por Flutter para compartir un `ChangeNotifier` entre pantallas.

**¿Qué diferencia hay entre `context.watch` y `context.read`?**
`watch` se suscribe: la pantalla se redibuja cada vez que el ViewModel cambia (se usa en `build`). `read` solo toma el ViewModel una vez para llamar un método (se usa en los botones).

**¿Por qué `if (!mounted) return;` después de cada `await`?**
Mientras se espera a Firebase el usuario pudo salir de la pantalla. Usar el `context` de una pantalla que ya no existe produce un error.

**¿Por qué `pushReplacement` y no `push`?**
Para que el login salga de la pila de pantallas: con "atrás" no se vuelve al formulario ya con la sesión abierta.

**¿Por qué solo cuentas `@udla.edu.co`?**
La app es para la universidad. Se valida dos veces: el formateador limpia lo que se escribe y el ViewModel rechaza cualquier otro dominio **antes** de llamar a Firebase.
