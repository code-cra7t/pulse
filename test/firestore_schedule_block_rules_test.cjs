// Run: firebase emulators:exec --only firestore --project demo-jotcue "node test/firestore_schedule_block_rules_test.cjs"
// Uses only the local emulator and Node's built-in fetch; never production.
const assert = require('node:assert/strict');

const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
  throw new Error('Run with a local Firestore emulator, never production.');
}
const project = 'demo-jotcue';
const userId = 'rules-tester';
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents/users/${userId}/scheduleBlocks`;
const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const token = `${encode({ alg: 'none', typ: 'JWT' })}.${encode({
  iss: `https://securetoken.google.com/${project}`, aud: project,
  sub: userId, user_id: userId, iat: now, exp: now + 3600,
  firebase: { sign_in_provider: 'custom', identities: {} },
})}.`;
const otherToken = `${encode({ alg: 'none', typ: 'JWT' })}.${encode({
  iss: `https://securetoken.google.com/${project}`, aud: project,
  sub: 'someone-else', user_id: 'someone-else', iat: now, exp: now + 3600,
  firebase: { sign_in_provider: 'custom', identities: {} },
})}.`;
const createdAt = { timestampValue: new Date().toISOString() };
const start = new Date(Date.now() + 3600_000);
const end = new Date(start.getTime() + 3600_000);
const updatedAt = { timestampValue: new Date().toISOString() };

function fields(id, revision = 1) {
  return {
    id: { stringValue: id },
    userId: { stringValue: userId },
    taskId: { stringValue: 'task-1' },
    title: { stringValue: 'Write chapter' },
    projectId: { nullValue: null },
    startsAt: { timestampValue: start.toISOString() },
    endsAt: { timestampValue: end.toISOString() },
    status: { stringValue: 'scheduled' },
    source: { stringValue: 'proposal' },
    createdAt,
    updatedAt,
    revision: { integerValue: String(revision) },
  };
}

async function write(id, bodyFields, expected, auth = token) {
  const response = await fetch(`${base}/${id}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${auth}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: bodyFields }),
  });
  const text = await response.text();
  assert.equal(response.status, expected, `${id}: ${text}`);
  return response;
}

(async () => {
  const id = `block-${Date.now()}`;
  await write(id, fields(id), 200);
  console.log('PASS valid-create');

  await write(`${id}-rev0`, fields(`${id}-rev0`, 0), 403);
  console.log('PASS reject-revision-zero');

  const wrongOwner = fields(`${id}-owner`);
  wrongOwner.userId = { stringValue: 'someone-else' };
  await write(`${id}-owner`, wrongOwner, 403);
  console.log('PASS reject-wrong-owner');

  const badStatus = fields(`${id}-status`);
  badStatus.status = { stringValue: 'moved' };
  await write(`${id}-status`, badStatus, 403);
  console.log('PASS reject-bad-status');

  const unexpected = fields(`${id}-extra`);
  unexpected.surprise = { booleanValue: true };
  await write(`${id}-extra`, unexpected, 403);
  console.log('PASS reject-unexpected-field');

  await write(id, fields(id, 2), 200);
  console.log('PASS sequential-revision-update');

  await write(id, fields(id, 4), 403);
  console.log('PASS reject-revision-jump');

  const changedCreated = fields(id, 3);
  changedCreated.createdAt = { timestampValue: new Date(Date.now() + 5000).toISOString() };
  await write(id, changedCreated, 403);
  console.log('PASS reject-created-at-change');

  await write(id, fields(id, 3), 403, otherToken);
  console.log('PASS reject-other-user-update');

  const deleted = await fetch(`${base}/${id}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${token}` },
  });
  assert.equal(deleted.status, 200, await deleted.text());
  console.log('PASS owner-delete');
  console.log('All 10 schedule-block rule checks passed.');
})().catch((error) => { console.error(error); process.exitCode = 1; });
