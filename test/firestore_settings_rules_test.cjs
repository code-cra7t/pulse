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

const schedulingFields = {
  isConfigured: { booleanValue: true },
  dayStartMinutes: { integerValue: '480' },
  dayEndMinutes: { integerValue: '1200' },
  availableWeekdays: {
    arrayValue: { values: [1, 2, 3, 4, 5].map((n) => ({ integerValue: String(n) })) },
  },
  minimumBlockMinutes: { integerValue: '30' },
  preferredBlockMinutes: { integerValue: '90' },
  breakMinutes: { integerValue: '15' },
  maxFocusMinutesPerDay: { integerValue: '360' },
  defaultTaskMinutes: { integerValue: '30' },
  protectLunch: { booleanValue: true },
  lunchStartMinutes: { integerValue: '750' },
  lunchEndMinutes: { integerValue: '810' },
};

const baseFields = {
  themeMode: { stringValue: 'system' },
  defaultNoteTag: { stringValue: 'Personal' },
  notificationsEnabled: { booleanValue: true },
  smartRemindersEnabled: { booleanValue: true },
  updatedAt: timestamp,
};

async function write(name, fields, expected, settingsId = 'app') {
  const url = `${root}/users/rules-tester/settings/${settingsId}`;
  const response = await fetch(url, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
  const text = await response.text();
  assert.equal(response.status, expected, `${name}: ${text}`);
  console.log(`PASS ${name}`);
}

(async () => {
  await write('legacy-settings-still-valid', { ...baseFields }, 200);
  await write('valid-scheduling-preferences', {
    ...baseFields,
    scheduling: { mapValue: { fields: schedulingFields } },
  }, 200);
  await write('invalid-day-window', {
    ...baseFields,
    scheduling: {
      mapValue: {
        fields: {
          ...schedulingFields,
          dayStartMinutes: { integerValue: '1000' },
          dayEndMinutes: { integerValue: '900' },
        },
      },
    },
  }, 403);
  await write('invalid-minimum-block', {
    ...baseFields,
    scheduling: {
      mapValue: {
        fields: {
          ...schedulingFields,
          minimumBlockMinutes: { integerValue: '5' },
        },
      },
    },
  }, 403);
  await write('unexpected-scheduling-field', {
    ...baseFields,
    scheduling: {
      mapValue: {
        fields: {
          ...schedulingFields,
          surprise: { booleanValue: true },
        },
      },
    },
  }, 403);
  await write('wrong-settings-document', {
    ...baseFields,
    scheduling: { mapValue: { fields: schedulingFields } },
  }, 403, 'other');
  console.log('All 6 settings rule checks passed.');
})().catch((error) => { console.error(error); process.exitCode = 1; });
