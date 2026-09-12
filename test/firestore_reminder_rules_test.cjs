// Run: firebase emulators:exec --only firestore --project demo-jotcue "node test/firestore_reminder_rules_test.cjs"
// Uses only the local emulator and Node's built-in HTTP client; no dependencies.
const assert = require('node:assert/strict');

const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
  throw new Error('Run with a local Firestore emulator, never production.');
}
const project = 'demo-jotcue';
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents/reminders`;
const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const token = `${encode({ alg: 'none', typ: 'JWT' })}.${encode({
  iss: `https://securetoken.google.com/${project}`, aud: project,
  sub: 'rules-tester', user_id: 'rules-tester', iat: now, exp: now + 3600,
  firebase: { sign_in_provider: 'custom', identities: {} },
})}.`;
const timestamp = { timestampValue: new Date().toISOString() };
const fields = {
  userId: { stringValue: 'rules-tester' }, noteId: { stringValue: 'note-1' },
  taskLineIndex: { nullValue: null }, notePreview: { stringValue: 'Water plants' },
  scheduledAt: timestamp, isCompleted: { booleanValue: false },
  repeat: { stringValue: 'none' }, notificationId: { integerValue: '123' },
  createdAt: timestamp, updatedAt: timestamp,
};

async function check(name, changes, expected) {
  const id = `test-${Date.now()}-${name}`;
  const response = await fetch(`${base}/${id}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: { ...fields, ...changes } }),
  });
  const text = await response.text();
  assert.equal(response.status, expected, `${name}: ${text}`);
  console.log(`PASS ${name}`);
  if (response.ok) {
    await fetch(`${base}/${id}`, { method: 'DELETE', headers: { Authorization: `Bearer ${token}` } });
  }
}

(async () => {
  await check('legacy-once', {}, 200);
  await check('legacy-daily', { repeat: { stringValue: 'daily' } }, 200);
  await check('stable-task-id', { taskId: { stringValue: 'task-123' } }, 200);
  await check('named-hourly', {
    title: { stringValue: 'Water plants' }, repeat: { stringValue: 'interval' },
    repeatIntervalMinutes: { integerValue: '60' },
  }, 200);
  await check('named-custom-90', {
    title: { stringValue: 'Stretch' }, repeat: { stringValue: 'interval' },
    repeatIntervalMinutes: { integerValue: '90' },
  }, 200);
  await check('once-null-interval', { repeatIntervalMinutes: { nullValue: null } }, 200);
  await check('interval-too-short', {
    repeat: { stringValue: 'interval' }, repeatIntervalMinutes: { integerValue: '14' },
  }, 403);
  await check('interval-missing', { repeat: { stringValue: 'interval' } }, 403);
  await check('interval-fractional', {
    repeat: { stringValue: 'interval' }, repeatIntervalMinutes: { doubleValue: 15.5 },
  }, 403);
  await check('wrong-owner', { userId: { stringValue: 'someone-else' } }, 403);
  await check('invalid-title', { title: { integerValue: '123' } }, 403);
  await check('invalid-task-id', { taskId: { integerValue: '123' } }, 403);
  await check('unexpected-field', { surprise: { booleanValue: true } }, 403);
  console.log('All 13 reminder rule checks passed.');
})().catch((error) => { console.error(error); process.exitCode = 1; });
