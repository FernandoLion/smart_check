# SmartCheck

Control de asistencia para la Universidad de la Amazonia (UDLA). El docente
abre un llamado desde su celular y los estudiantes que están en el aula quedan
presentes sin pasar lista: la app comprueba dónde están, que sean ellos y que
su celular esté cerca del docente.

App Android hecha en Flutter, con Firebase (Auth y Firestore) y la plataforma
Chairá de la universidad para verificar a cada persona.

## Cómo se marca la asistencia

**Docente**

1. Crea el curso con su horario, marca la **zona del aula** (de pie en el
   aula, con el GPS) e inscribe a los estudiantes por cédula, por correo o
   pegando la lista de Chairá.
2. A la hora de clase toca **Iniciar radar**. Se abre un llamado de 10
   minutos y el celular empieza a escuchar por Bluetooth.
3. Ve en vivo quién va quedando presente. Al cerrarse el llamado puede pasar
   lista a mano a los que faltan: deslizar a la derecha es presente, a la
   izquierda ausente y hacia arriba falta justificada.

El radar solo se abre dentro del horario del curso (o de una clase extra), en
la zona del aula, si el curso tiene estudiantes y no está archivado.

**Estudiante**

Cuando su docente abre el llamado, toca **Registrar asistencia** y la app
comprueba, en este orden:

1. **Ubicación:** que esté dentro de la zona del aula.
2. **Celular vinculado:** que marque desde el celular atado a su cuenta.
3. **Rostro:** prueba de vida (parpadeo) y comparación de su cara con su foto
   de Chairá. La comparación se hace en el celular con MobileFaceNet; la cara
   se guarda cifrada solo en ese celular.
4. **Firma y baliza:** firma su presencia en Firestore y anuncia por
   Bluetooth un código de 4 bytes. El radar del docente lo oye y lo registra
   presente.

El servidor solo acepta la asistencia por Bluetooth si el estudiante firmó su
presencia, desde su celular vinculado y dentro del llamado.

## Seguridad

Las reglas de Firestore (`firestore.rules`) hacen cumplir en el servidor:

- cada uno lee solo su perfil, y nadie puede cambiarse el rol;
- un curso lo ven su docente y sus inscritos;
- el llamado dura 10 minutos como máximo, contados con la hora del servidor;
- solo el docente escribe asistencias, y por Bluetooth solo con la firma del
  estudiante;
- un curso archivado es de solo lectura.

**Limitaciones conocidas**

- El rol (docente o estudiante) lo asigna la app según Chairá al
  registrarse; cerrarlo del todo en el servidor necesita una Cloud Function.
- La ubicación y el rostro se comprueban en el celular del estudiante: el
  servidor no tiene cómo verificarlos sin un backend propio.

## Arquitectura

MVVM con Provider:

```
lib/
  models/      datos (curso, sesión, asistencia, perfil...)
  services/    Firebase, Chairá, Bluetooth, GPS, rostro
  viewmodels/  estado y lógica de cada pantalla
  views/       pantallas del docente, del estudiante y de la asistencia
  widgets/     piezas compartidas
```

Firestore:

```
usuarios/{uid}                    perfil, rol y celular vinculado
cursos/{id}                       curso, horario, zona, inscritos
  inscritos/{cédula o correo}
  sesiones/{id}                   cada llamado
    asistencias/{clave}           lo que registra el docente
    presencias/{clave}            la firma del estudiante
```

## Cómo correrla

Requisitos: Flutter 3.47 o más reciente y un celular Android con Bluetooth,
GPS y cámara frontal.

```bash
flutter pub get
flutter run --release
```

APK para instalar a mano:

```bash
flutter build apk --release
```

Queda en `build/app/outputs/flutter-apk/app-release.apk`.

## Pruebas

Pruebas de la app (lógica y pantallas, sin celular):

```bash
flutter test
```

Pruebas de las reglas de Firestore, contra el emulador (necesita Java 11 o
más reciente; ver la cabecera de `test_reglas/reglas.test.mjs`):

```bash
npm install
npm run test:reglas
```

### Firebase local

Para probar la app completa sin tocar la base real, con los emuladores de
Firebase y datos de prueba: ver los pasos en `tool/emulador/sembrar.mjs`.
