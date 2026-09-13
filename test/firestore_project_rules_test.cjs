// Run: firebase emulators:exec --only firestore --project demo-jotcue "node test/firestore_project_rules_test.cjs"
// Uses only the local emulator and Node's built-in HTTP client; no dependencies.
const assert = require('node:assert/strict');

const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
  throw new Error('Run with a local Firestore emulator, never production.');
}
const project = 'demo-jotcue';
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents/projects`;
const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const token = `${encode({ alg: 'none', typ: 'JWT' })}.${encode({
  iss: `https://securetoken.google.com/${project}`, aud: project,
  sub: 'rules-tester', user_id: 'rules-tester', iat: now, exp: now + 3600,
  firebase: { sign_in_provider: 'custom', identities: {} },
})}.`;
const timestamp = { timestampValue: new Date().toISOString() };
const fields = {
  userId: { stringValue: 'rules-tester' },
  name: { stringValue: 'Life insurance exam' },
  description: { stringValue: 'Prepare for October' },
  status: { stringValue: 'active' },
  priority: { stringValue: 'critical' },
  deadline: timestamp,
  targetMinutesPerWeek: { integerValue: '600' },
  createdAt: timestamp,
  updatedAt: timestamp,
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
    await fetch(`${base}/${id}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
  }
}

(async () => {
  await check('valid-project', {}, 200);
  await check('nullable-planning-fields', {
    deadline: { nullValue: null },
    targetMinutesPerWeek: { nullValue: null },
    priority: { stringValue: 'none' },
  }, 200);
  await check('wrong-owner', { userId: { stringValue: 'someone-else' } }, 403);
  await check('empty-name', { name: { stringValue: '' } }, 403);
  await check('invalid-status', { status: { stringValue: 'deleted' } }, 403);
  await check('invalid-priority', { priority: { stringValue: 'urgent' } }, 403);
  await check('negative-weekly-target', {
    targetMinutesPerWeek: { integerValue: '-1' },
  }, 403);
  await check('unexpected-field', { surprise: { booleanValue: true } }, 403);
  console.log('All 8 project rule checks passed.');
})().catch((error) => { console.error(error); process.exitCode = 1; });
