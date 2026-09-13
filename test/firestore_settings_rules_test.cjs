// Run: firebase emulators:exec --only firestore --project demo-jotcue "node test/firestore_settings_rules_test.cjs"
// Uses only the local emulator and Node's built-in fetch; no dependencies.
const assert = require('node:assert/strict');

const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
  throw new Error('Run with a local Firestore emulator, never production.');
}
const project = 'demo-jotcue';
const root = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const token = `${encode({ alg: 'none', typ: 'JWT' })}.${encode({
  iss: `https://securetoken.google.com/${project}`, aud: project,
  sub: 'rules-tester', user_id: 'rules-tester', iat: now, exp: now + 3600,
  firebase: { sign_in_provider: 'custom', identities: {} },
})}.`;
const timestamp = { timestampValue: new Date().toISOString() };

const baseFields = {
  themeMode: { stringValue: 'system' },
  defaultNoteTag: { stringValue: 'Personal' },
  notificationsEnabled: { booleanValue: true },
  smartRemindersEnabled: { booleanValue: true },
  updatedAt: timestamp,
};

async function write(name, fields, expected, settingsId = 'app', authToken = token) {
  const url = `${root}/users/rules-tester/settings/${settingsId}`;
  const headers = { 'Content-Type': 'application/json' };
  if (authToken) headers.Authorization = `Bearer ${authToken}`;
  const response = await fetch(url, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({ fields }),
  });
  const responseText = await response.text();
  assert.equal(response.status, expected, `${name}: ${responseText}`);
  console.log(`PASS ${name}`);
}

const automation = (level) => ({
  mapValue: { fields: { level: { stringValue: level } } },
});

(async () => {
  await write('legacy-settings-still-valid', { ...baseFields }, 200);
  for (const level of ['observe', 'suggest', 'approval', 'trusted']) {
    await write(`valid-automation-${level}`, {
      ...baseFields,
      automation: automation(level),
    }, 200);
  }
  await write('invalid-automation-level', {
    ...baseFields,
    automation: automation('unbounded'),
  }, 403);
  await write('unexpected-automation-field', {
    ...baseFields,
    automation: {
      mapValue: {
        fields: {
          level: { stringValue: 'suggest' },
          autoEverything: { booleanValue: true },
        },
      },
    },
  }, 403);
  await write('wrong-settings-document', { ...baseFields }, 403, 'other');
  await write('unauthenticated-write', { ...baseFields }, 403, 'app', null);
  console.log('All 9 settings rule checks passed.');
})().catch((error) => { console.error(error); process.exitCode = 1; });
