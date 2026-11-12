import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { initializeTestEnvironment } = require('@firebase/rules-unit-testing');
const { doc, setDoc, deleteDoc, serverTimestamp } = require('firebase/firestore');
const env = await initializeTestEnvironment({
  projectId:'demo-hw02-board', firestore:{host:'127.0.0.1',port:8180},
});
try {
  const db = env.authenticatedContext('second-window').firestore();
  const message = doc(db,'Messages/live-second-window');
  if (process.argv[2] === 'delete') await deleteDoc(message);
  else await setDoc(message, {
    authorUid:'second-window', text:'Live update from the second client',
    createdAt:serverTimestamp(), updatedAt:serverTimestamp(),
  });
  console.log(process.argv[2] === 'delete' ? 'Second client removed its post' : 'Second client created its post');
} finally {
  await env.cleanup();
}
