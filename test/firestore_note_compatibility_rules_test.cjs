// Run: firebase emulators:exec --only firestore --project demo-jotcue "node test/firestore_note_compatibility_rules_test.cjs"
// Uses only the local emulator and Node's built-in fetch; never production.
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

function taskIdentity(text, priority = 'none') {
  return {
    mapValue: {
      fields: {
        id: { stringValue: 'task-1' },
        lineIndex: { integerValue: '0' },
        text: { stringValue: text },
        projectId: { nullValue: null },
        dueAtMs: { nullValue: null },
        priority: { stringValue: priority },
        estimatedMinutes: { nullValue: null },
        isFlexible: { booleanValue: true },
        dependsOnTaskIds: { arrayValue: { values: [] } },
        waitingFor: { nullValue: null },
      },
    },
  };
}

function noteFields({
  title = 'Note',
  identityText = 'Task',
  contentText,
  includeIdentity = true,
  priority = 'none',
  schema,
  writeToken,
} = {}) {
  const fields = {
    userId: { stringValue: 'rules-tester' },
    title: { stringValue: title },
    isPinned: { booleanValue: false },
    createdAt: timestamp,
    updatedAt: timestamp,
    tags: { arrayValue: { values: [] } },
    content: { stringValue: contentText ?? `- ${identityText}` },
    color: { integerValue: '4294967295' },
    images: { arrayValue: { values: [] } },
    taskIdentities: {
      arrayValue: {
        values: includeIdentity ? [taskIdentity(identityText, priority)] : [],
      },
    },
  };
  if (schema !== undefined) {
    fields.taskMetadataSchemaVersion = { integerValue: String(schema) };
  }
  if (writeToken !== undefined) {
    fields.taskMetadataWriteToken = { stringValue: writeToken };
  }
  return fields;
}

async function write(name, noteId, fields, expected, log = true) {
  const response = await fetch(`${root}/notes/${noteId}`, {
    method: 'PATCH',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
  const text = await response.text();
  assert.equal(response.status, expected, `${name}: ${text}`);
  if (log) console.log(`PASS ${name}`);
}

(async () => {
  await write('legacy-create-valid', 'legacy-create', noteFields(), 200);
  await write('modern-create-valid', 'modern-create', noteFields({
    schema: 1, writeToken: 'token-a',
  }), 200);
  await write('half-guard-rejected', 'half-guard', noteFields({ schema: 1 }), 403);

  await write('legacy-harmless-seed', 'legacy-harmless', noteFields(), 200, false);
  await write('legacy-harmless-title-update-allowed', 'legacy-harmless', noteFields({
    title: 'Renamed',
  }), 200);


  await write('legacy-content-seed', 'legacy-content', noteFields(), 200, false);
  await write('legacy-task-bearing-content-edit-rejected', 'legacy-content', noteFields({
    contentText: 'Intro\n- Task',
  }), 403);

  await write('legacy-plain-seed', 'legacy-plain', noteFields({
    includeIdentity: false, contentText: 'Plain text',
  }), 200, false);
  await write('legacy-non-task-content-edit-allowed', 'legacy-plain', noteFields({
    includeIdentity: false, contentText: 'Changed plain text',
  }), 200);

  await write('legacy-task-change-seed', 'legacy-task-change', noteFields(), 200, false);
  await write('legacy-task-identity-change-rejected', 'legacy-task-change', noteFields({
    identityText: 'Changed by old app',
  }), 403);
  await write('legacy-note-modern-upgrade-allowed', 'legacy-task-change', noteFields({
    identityText: 'Changed safely', schema: 1, writeToken: 'upgrade-token',
  }), 200);

  await write('protected-seed', 'protected-note', noteFields({
    schema: 1, writeToken: 'protected-a',
  }), 200, false);
  await write('protected-harmless-update-same-token-allowed', 'protected-note', noteFields({
    title: 'Renamed safely', schema: 1, writeToken: 'protected-a',
  }), 200);
  await write('protected-old-style-identity-change-rejected', 'protected-note', noteFields({
    identityText: 'Lossy edit', schema: 1, writeToken: 'protected-a',
  }), 403);
  await write('protected-modern-identity-change-fresh-token-allowed', 'protected-note', noteFields({
    identityText: 'Modern edit', priority: 'high', schema: 1, writeToken: 'protected-b',
  }), 200);


  await write('protected-content-seed', 'protected-content', noteFields({
    schema: 1, writeToken: 'content-a',
  }), 200, false);
  await write('protected-content-change-same-token-rejected', 'protected-content', noteFields({
    contentText: 'Intro\n- Task', schema: 1, writeToken: 'content-a',
  }), 403);
  await write('protected-content-change-fresh-token-allowed', 'protected-content', noteFields({
    contentText: 'Intro\n- Task', schema: 1, writeToken: 'content-b',
  }), 200);

  await write('schema-two-seed', 'schema-two', noteFields({
    schema: 2, writeToken: 'schema-two-a',
  }), 200, false);
  await write('schema-downgrade-rejected', 'schema-two', noteFields({
    title: 'Downgrade', schema: 1, writeToken: 'schema-two-b',
  }), 403);

  await write('drop-guard-seed', 'drop-guard', noteFields({
    schema: 1, writeToken: 'drop-a',
  }), 200, false);
  await write('dropping-modern-guard-rejected', 'drop-guard', noteFields(), 403);

  await write('overlong-token-rejected', 'long-token', noteFields({
    schema: 1, writeToken: 'x'.repeat(129),
  }), 403);

  console.log('All 16 note compatibility rule checks passed.');
})().catch((error) => { console.error(error); process.exitCode = 1; });
