// Siembra el Firebase de prueba (emuladores de Auth y Firestore de este PC)
// con una cuenta docente+estudiante y dos cursos con historia, para probar
// la app completa sin tocar producción.
//
// 1. Levantar los emuladores (ver la cabecera de test_reglas/reglas.test.mjs
//    para el Java en Windows):
//      npx firebase emulators:start --only auth,firestore --project smart-check-8bd33
// 2. Sembrar:
//      node tool/emulador/sembrar.mjs
// 3. Con el celular por USB, que vea los emuladores del PC como suyos:
//      adb reverse tcp:9099 tcp:9099
//      adb reverse tcp:8080 tcp:8080
// 4. Correr la app contra ellos:
//      flutter run --dart-define=USE_FIREBASE_EMULATOR=true \
//        --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
//
// Las credenciales de aquí solo existen en el emulador.

const PROYECTO = 'smart-check-8bd33';
const AUTH = 'http://127.0.0.1:9099';
const FIRESTORE = `http://127.0.0.1:8080/v1/projects/${PROYECTO}/databases/(default)/documents`;

export const CUENTA_PRUEBA = {
  correo: 'claude.prueba@udla.edu.co',
  clave: 'Emulador-2026',
  nombre: 'CLAUDE PRUEBA DOCENTE',
  cedula: '9000000001',
};

/** Convierte un valor de JS al formato de la API REST de Firestore. */
function valor(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(valor) } };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') {
    return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  }
  if (typeof v === 'object') {
    return {
      mapValue: {
        fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, valor(x)])),
      },
    };
  }
  return { stringValue: String(v) };
}

/** Escribe un documento saltándose las reglas (el emulador acepta "owner"). */
async function poner(ruta, datos) {
  const r = await fetch(`${FIRESTORE}/${ruta}`, {
    method: 'PATCH',
    headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fields: Object.fromEntries(Object.entries(datos).map(([k, v]) => [k, valor(v)])),
    }),
  });
  if (!r.ok) throw new Error(`${ruta}: ${r.status} ${await r.text()}`);
}

async function cuenta(correo, clave) {
  const r = await fetch(
    `${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulador`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: correo, password: clave, returnSecureToken: true }),
    },
  );
  const datos = await r.json();
  if (!r.ok) throw new Error(`cuenta ${correo}: ${JSON.stringify(datos)}`);
  return datos.localId;
}

/** "HH:mm" de una fecha. */
const hhmm = (d) =>
  `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
/** Día ISO (lunes 1 ... domingo 7). */
const diaIso = (d) => ((d.getDay() + 6) % 7) + 1;

async function main() {
  // Borra lo sembrado antes, para poder repetir.
  await fetch(`${AUTH}/emulator/v1/projects/${PROYECTO}/accounts`, { method: 'DELETE' });
  await fetch(`${FIRESTORE.replace('/v1/', '/emulator/v1/')}`, { method: 'DELETE' });

  const p = CUENTA_PRUEBA;
  const uid = await cuenta(p.correo, p.clave);
  await poner(`usuarios/${uid}`, {
    email: p.correo,
    nombre: p.nombre,
    cedula: p.cedula,
    programa: 'INGENIERIA DE SISTEMAS',
    tipo_usuario: 'DOCENTE',
    foto_url: null,
    roles: ['docente', 'estudiante'],
  });

  const ahora = new Date();
  // Bloque de clase que contiene este momento: así el radar se puede abrir.
  const inicio = new Date(ahora.getTime() - 60 * 60_000);
  const fin = new Date(ahora.getTime() + 2 * 60 * 60_000);
  const enMismoDia = fin.getDate() === ahora.getDate();

  const inscritos = [
    { cedula: p.cedula, email: p.correo, nombre: p.nombre },
    { cedula: '9000000002', email: 'ana.prueba@udla.edu.co', nombre: 'ANA PRUEBA GOMEZ' },
    { cedula: '9000000003', email: null, nombre: 'BETO PRUEBA RUIZ' },
    { cedula: null, email: 'caro.prueba@udla.edu.co', nombre: 'CAROLINA PRUEBA' },
  ];
  const clave = (i) => i.cedula ?? i.email;
  const claves = inscritos.flatMap((i) => [i.cedula, i.email].filter(Boolean));

  await poner('cursos/isw2', {
    codigo: 'ISW2',
    nombre: 'Ingeniería de Software II',
    grupo: '1',
    aula: 'Bloque 4 - 201',
    periodo: '2026-2',
    docente_uid: uid,
    docente_nombre: p.nombre,
    horarios: [
      {
        dia: diaIso(ahora),
        inicio: hhmm(inicio),
        fin: enMismoDia ? hhmm(fin) : '23:59',
      },
    ],
    geocerca: null,
    claves_inscritos: claves,
    total_inscritos: inscritos.length,
    archivado: false,
  });
  for (const i of inscritos) {
    await poner(`cursos/isw2/inscritos/${clave(i)}`, { ...i, uid: null });
  }
  // Tres clases ya cerradas, la última hace dos días.
  const asistieron = [
    [true, true, false, true],
    [true, false, false, true],
    [true, true, true, false],
  ];
  for (let s = 0; s < 3; s++) {
    const dia = new Date(ahora.getTime() - (2 + 7 * s) * 86_400_000);
    dia.setHours(8, 0, 0, 0);
    const id = `pasada${s + 1}`;
    await poner(`cursos/isw2/sesiones/${id}`, {
      inicio: dia,
      fin: new Date(dia.getTime() + 10 * 60_000),
      abierta: false,
      bloque_inicio: dia,
    });
    for (let k = 0; k < inscritos.length; k++) {
      if (!asistieron[s][k]) continue;
      await poner(`cursos/isw2/sesiones/${id}/asistencias/${clave(inscritos[k])}`, {
        estado: 'presente',
        metodo: k === 2 ? 'manual' : 'ble',
        hora: new Date(dia.getTime() + (3 + k) * 60_000),
        registrado_por: uid,
      });
    }
  }

  // Un curso sin clase hoy, para archivar, editar y borrar.
  const otroDia = (diaIso(ahora) % 7) + 1;
  await poner('cursos/bd1', {
    codigo: 'BD1',
    nombre: 'Bases de Datos I',
    grupo: '2',
    aula: 'Sala 3',
    periodo: '2026-2',
    docente_uid: uid,
    docente_nombre: p.nombre,
    horarios: [{ dia: otroDia, inicio: '14:00', fin: '16:00' }],
    geocerca: null,
    claves_inscritos: [],
    total_inscritos: 0,
    archivado: false,
  });

  console.log(`Listo: ${p.correo} (uid ${uid}), cursos isw2 y bd1.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
