// Pruebas de firestore.rules: lo único que el servidor hace cumplir, así que
// lo que aquí falle, lo puede hacer cualquiera con un APK modificado.
//
// Se corren contra el emulador de Firestore (necesita Java 11 o más reciente):
//
//   npm install
//   npm run test:reglas
//
// En Windows, si el `java` del PATH es viejo, sirve el de Android Studio; y
// el JDK reciente necesita un directorio corto para sus sockets, o el
// emulador muere con "Unable to establish loopback connection":
//
//   export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"
//   export PATH="$JAVA_HOME/bin:$PATH"
//   export JAVA_TOOL_OPTIONS='-Djdk.net.unixdomain.tmpdir=C:\Users\<tú>\jtmp'
//
// `firebase emulators:exec` levanta el emulador, deja su dirección en
// FIRESTORE_EMULATOR_HOST y lo apaga al terminar. El proyecto `demo-*` no
// existe en la nube: nada de esto puede tocar producción.
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

/** Cuándo ató cada estudiante su celular (lo repite su firma). */
const VINCULADO = Timestamp.fromMillis(Date.UTC(2026, 9, 1, 13, 0));
const CELULAR_ANA = 'celular-ana-001';
const CELULAR_BETO = 'celular-beto-02';

let entorno;

before(async () => {
  entorno = await initializeTestEnvironment({
    projectId: 'demo-smart-check',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});

after(() => entorno.cleanup());

beforeEach(async () => {
  await entorno.clearFirestore();
  await sembrar();
});

/** Un docente, dos inscritos con su celular y un llamado abierto ahora. */
async function sembrar() {
  const ahora = Date.now();
  await entorno.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'usuarios/docente'), {
      roles: ['docente'],
      cedula: 'D1',
    });
    await setDoc(doc(db, 'usuarios/ana'), {
      roles: ['estudiante'],
      cedula: '111',
      dispositivo_id: CELULAR_ANA,
      dispositivo_desde: VINCULADO,
    });
    await setDoc(doc(db, 'usuarios/ana/dispositivos/r1'), {
      dispositivo_id: CELULAR_ANA,
      desde: VINCULADO,
      anterior: null,
    });
    await setDoc(doc(db, 'usuarios/beto'), {
      roles: ['estudiante'],
      cedula: '222',
      dispositivo_id: CELULAR_BETO,
      dispositivo_desde: VINCULADO,
    });
    await setDoc(doc(db, 'cursos/c1'), {
      docente_uid: 'docente',
      claves_inscritos: ['111', '222'],
    });
    // El llamado de ahora: empezó hace un minuto y dura diez.
    await setDoc(doc(db, 'cursos/c1/sesiones/s1'), {
      abierta: true,
      inicio: Timestamp.fromMillis(ahora - 60_000),
      fin: Timestamp.fromMillis(ahora + 9 * 60_000),
      bloque_inicio: Timestamp.fromMillis(ahora - 5 * 60_000),
    });
    // Uno de ayer, ya cerrado.
    await setDoc(doc(db, 'cursos/c1/sesiones/ayer'), {
      abierta: false,
      inicio: Timestamp.fromMillis(ahora - 86_400_000),
      fin: Timestamp.fromMillis(ahora - 86_400_000 + 600_000),
      bloque_inicio: Timestamp.fromMillis(ahora - 86_400_000),
    });
  });
}

const comoDocente = () =>
  entorno
    .authenticatedContext('docente', { email: 'docente@udla.edu.co' })
    .firestore();
const comoAna = () =>
  entorno.authenticatedContext('ana', { email: 'ana@udla.edu.co' }).firestore();

/** La firma que deja el celular de Ana, con lo que se le cambie. */
const firmaDeAna = (cambios = {}) => ({
  creado_en: serverTimestamp(),
  dispositivo: CELULAR_ANA,
  vinculado_en: VINCULADO,
  biometria: 'biometrica',
  ...cambios,
});

const asistencia = (metodo) => ({
  estado: 'presente',
  metodo,
  hora: serverTimestamp(),
  registrado_por: 'docente',
});

/** Deja puesta la firma de [clave] en el llamado, sin pasar por las reglas. */
async function firmar(clave, sesion = 's1') {
  await entorno.withSecurityRulesDisabled((ctx) =>
    setDoc(doc(ctx.firestore(), `cursos/c1/sesiones/${sesion}/presencias/${clave}`), {
      creado_en: Timestamp.now(),
      dispositivo: CELULAR_ANA,
      vinculado_en: VINCULADO,
      biometria: 'biometrica',
    }),
  );
}

describe('perfil', () => {
  test('nadie se cambia el rol', async () => {
    await assertFails(
      updateDoc(doc(comoAna(), 'usuarios/ana'), {
        roles: ['docente', 'estudiante'],
      }),
    );
  });

  test('vincular otro celular con la hora del servidor sí se puede', async () => {
    // Sin espera entre cambios: la app exige antes la cara (ca22b1d).
    await assertSucceeds(
      updateDoc(doc(comoAna(), 'usuarios/ana'), {
        dispositivo_id: 'celular-nuevo-9',
        dispositivo_desde: serverTimestamp(),
      }),
    );
  });

  test('con una fecha puesta por el celular, no', async () => {
    await assertFails(
      updateDoc(doc(comoAna(), 'usuarios/ana'), {
        dispositivo_id: 'celular-nuevo-9',
        dispositivo_desde: Timestamp.fromMillis(0),
      }),
    );
  });

  test('un identificador de celular demasiado corto no se acepta', async () => {
    await assertFails(
      updateDoc(doc(comoAna(), 'usuarios/ana'), {
        dispositivo_id: 'corto',
        dispositivo_desde: serverTimestamp(),
      }),
    );
  });

  test('el perfil de otro no se lee ni se toca', async () => {
    const db = comoAna();
    await assertFails(getDoc(doc(db, 'usuarios/beto')));
    await assertFails(
      updateDoc(doc(db, 'usuarios/beto'), {
        dispositivo_id: CELULAR_ANA,
        dispositivo_desde: serverTimestamp(),
      }),
    );
  });

  test('un perfil no se borra', async () => {
    await assertFails(deleteDoc(doc(comoAna(), 'usuarios/ana')));
  });
});

describe('historial de celulares', () => {
  test('se le añade un cambio con la hora del servidor', async () => {
    await assertSucceeds(
      addDoc(collection(comoAna(), 'usuarios/ana/dispositivos'), {
        dispositivo_id: 'celular-nuevo-9',
        desde: serverTimestamp(),
        anterior: CELULAR_ANA,
      }),
    );
  });

  test('no se corrige ni se borra', async () => {
    const registro = doc(comoAna(), 'usuarios/ana/dispositivos/r1');
    await assertFails(updateDoc(registro, { dispositivo_id: 'otro-celular' }));
    await assertFails(deleteDoc(registro));
  });
});

describe('firma del estudiante', () => {
  const presencia = (db, clave, sesion = 's1') =>
    doc(db, `cursos/c1/sesiones/${sesion}/presencias/${clave}`);

  test('firma su propia presencia desde su celular, en la ventana', async () => {
    await assertSucceeds(setDoc(presencia(comoAna(), '111'), firmaDeAna()));
  });

  test('no firma por un compañero', async () => {
    await assertFails(setDoc(presencia(comoAna(), '222'), firmaDeAna()));
  });

  test('no firma desde un celular que no es el suyo', async () => {
    await assertFails(
      setDoc(
        presencia(comoAna(), '111'),
        firmaDeAna({ dispositivo: CELULAR_BETO }),
      ),
    );
  });

  test('no miente sobre cuándo vinculó el celular', async () => {
    await assertFails(
      setDoc(
        presencia(comoAna(), '111'),
        firmaDeAna({ vinculado_en: Timestamp.fromMillis(0) }),
      ),
    );
  });

  test('la hora de la firma la pone el servidor', async () => {
    await assertFails(
      setDoc(
        presencia(comoAna(), '111'),
        firmaDeAna({ creado_en: Timestamp.fromMillis(0) }),
      ),
    );
  });

  test('con el llamado cerrado no se firma', async () => {
    await assertFails(
      setDoc(presencia(comoAna(), '111', 'ayer'), firmaDeAna()),
    );
  });

  test('una firma no se retoca', async () => {
    await firmar('111');
    await assertFails(
      updateDoc(presencia(comoAna(), '111'), { biometria: 'no_disponible' }),
    );
  });
});

describe('asistencia (la otra llave)', () => {
  const marca = (db, clave, sesion = 's1') =>
    doc(db, `cursos/c1/sesiones/${sesion}/asistencias/${clave}`);

  test('por BLE, con la firma del estudiante, se registra', async () => {
    await firmar('111');
    await assertSucceeds(setDoc(marca(comoDocente(), '111'), asistencia('ble')));
  });

  test('por BLE, sin firma, no', async () => {
    await assertFails(setDoc(marca(comoDocente(), '222'), asistencia('ble')));
  });

  test('a mano, sin firma, sí: es la corrección del docente', async () => {
    await assertSucceeds(
      setDoc(marca(comoDocente(), '222'), asistencia('manual')),
    );
  });

  test('a mano también después de cerrado el llamado', async () => {
    await assertSucceeds(
      setDoc(marca(comoDocente(), '222', 'ayer'), asistencia('manual')),
    );
  });

  test('por BLE, después de cerrado el llamado, no', async () => {
    await firmar('111', 'ayer');
    await assertFails(
      setDoc(marca(comoDocente(), '111', 'ayer'), asistencia('ble')),
    );
  });

  test('a alguien que no está inscrito no se le marca', async () => {
    await assertFails(
      setDoc(marca(comoDocente(), '999'), asistencia('manual')),
    );
  });

  test('el estudiante no se marca solo', async () => {
    await firmar('111');
    await assertFails(
      setDoc(marca(comoAna(), '111'), {
        ...asistencia('ble'),
        registrado_por: 'ana',
      }),
    );
  });
});
