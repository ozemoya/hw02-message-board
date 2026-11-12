import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
const { assertFails, assertSucceeds, initializeTestEnvironment } = createRequire(import.meta.url)('@firebase/rules-unit-testing');
const { collection, deleteDoc, doc, getDocFromServer, getDocs, onSnapshot, orderBy, query, runTransaction, serverTimestamp, setDoc, updateDoc } = createRequire(import.meta.url)('firebase/firestore');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-hw02-board',
    firestore: { host: '127.0.0.1', port: 8180, rules: await readFile('firestore.rules', 'utf8') },
  });
});
after(async () => { await env?.cleanup(); });

const payload = (authorUid, text) => ({authorUid, text, createdAt: serverTimestamp(), updatedAt: serverTimestamp()});
const row = (db, id) => doc(db, 'Messages', id);

test('signed-out board read is denied', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDocs(collection(db, 'Messages')));
});

test('another member cannot update or delete an authored message', async () => {
  const a = env.authenticatedContext('test-a').firestore();
  const b = env.authenticatedContext('test-b').firestore();
  await assertSucceeds(setDoc(row(a, 'rules-cross'), payload('test-a', 'Owned by A')));
  await assertFails(updateDoc(row(b, 'rules-cross'), {text:'Changed by B', updatedAt:serverTimestamp()}));
  await assertFails(deleteDoc(row(b, 'rules-cross')));
  await assertSucceeds(deleteDoc(row(a, 'rules-cross')));
});

test('forged author is denied and the real author can complete CRUD', async () => {
  const db = env.authenticatedContext('test-a').firestore();
  const ref = row(db, 'rules-crud');
  await assertFails(setDoc(ref, payload('test-b', 'Forged author')));
  await assertSucceeds(setDoc(ref, payload('test-a', 'First message')));
  assert.equal((await assertSucceeds(getDocFromServer(ref))).get('text'), 'First message');
  await assertSucceeds(updateDoc(ref, {text:'Edited', updatedAt:serverTimestamp()}));
  assert.equal((await getDocFromServer(ref)).get('text'), 'Edited');
  await assertSucceeds(deleteDoc(ref));
  assert.equal((await getDocFromServer(ref)).exists(), false);
});

test('profile writes five fields and stays private', async () => {
  const a = env.authenticatedContext('profile-a').firestore();
  const b = env.authenticatedContext('test-b').firestore();
  const ref = doc(a, 'Users/profile-a');
  await assertSucceeds(setDoc(ref, {
    uid: 'profile-a', firstName:'Ada', lastName:'Demo', role:'member', registrationDateTime:serverTimestamp(),
  }));
  const data = (await getDocFromServer(ref)).data();
  assert.deepEqual(Object.keys(data).sort(), ['firstName','lastName','registrationDateTime','role','uid']);
  await assertFails(getDocFromServer(doc(b, 'Users/profile-a')));
});

test('two calls using one document ID produce one post and a second client sees it live', async () => {
  const a = env.authenticatedContext('test-a').firestore();
  const b = env.authenticatedContext('test-b').firestore();
  const ref = row(a, 'rules-retry');
  const post = () => runTransaction(a, async transaction => {
    if ((await transaction.get(ref)).exists()) return;
    transaction.set(ref, payload('test-a', 'One post after retry'));
  });
  let stop;
  let timer;
  const live = new Promise((resolve, reject) => {
    timer = setTimeout(() => reject(new Error('Board did not receive the live update')), 10000);
    stop = onSnapshot(query(collection(b, 'Messages'), orderBy('createdAt', 'desc')), snapshot => {
      if (snapshot.docs.some(item => item.id === ref.id)) resolve();
    }, reject);
  });
  try {
    await post();
    const original = (await getDocFromServer(ref)).get('createdAt');
    await post();
    await live;
    const matching = (await getDocs(collection(b, 'Messages'))).docs.filter(item => item.id === ref.id);
    assert.equal(matching.length, 1);
    assert.ok(matching[0].get('createdAt').isEqual(original));
  } finally {
    clearTimeout(timer);
    stop?.();
    await deleteDoc(ref);
  }
});


