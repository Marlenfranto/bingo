#!/usr/bin/env node
// Seeds the active game + 15 starter questions into Firestore.
//
// Usage:
//   GOOGLE_APPLICATION_CREDENTIALS=./service-account.json \
//     node scripts/seed_questions.mjs [gameId]
//
// Default gameId is "default-game" (must match ACTIVE_GAME_ID in .env).

import admin from 'firebase-admin';
import { readFileSync } from 'node:fs';

const gameId = process.argv[2] ?? 'default-game';
const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;

if (!credPath) {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS to a service-account JSON path.');
  console.error('Download from: Firebase Console → Project Settings → Service accounts → Generate new private key.');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(readFileSync(credPath, 'utf8'))),
});

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const QUESTIONS = [
  'Find someone who has worked with a client from another country.',
  'Find someone who has deployed an application to production.',
  'Find someone who has handled a last-minute production issue.',
  'Find someone who has presented a demo to a client or management.',
  'Find someone who has worked on both web and mobile projects.',
  'Find someone who has experience with cloud platforms like AWS, Azure, or GCP.',
  'Find someone who has used AI tools to improve productivity at work.',
  'Find someone who has collaborated with more than three teams on a project.',
  'Find someone who has attended a hackathon or tech event.',
  'Find someone who has created UI designs using Figma or Adobe XD.',
  'Find someone who has experience with Agile or Scrum methodology.',
  'Find someone who has worked directly with customers or clients.',
  'Find someone who has automated a repetitive task at work.',
  'Find someone who has experience in sales pitches or product presentations.',
  'Find someone who has worked on a project involving AR, VR, or XR.',
  'Find someone who has experience with DevOps tools like Docker, Jenkins, or Kubernetes.',
  'Find someone who has stayed late in the office to meet a project deadline.',
  'Find someone who has mentored an intern or new joiner.',
  'Find someone who joined the company within the last 1 months.',
  'Find someone who has worked on a live client implementation.',
  'Find someone who has designed or created 3D assets or animations.',
  'Find someone who has experience with frontend frameworks like React, Angular, or Vue.',
  'Find someone who has built or maintained backend APIs.',
  'Find someone who has participated in recruitment interviews or onboarding.',
  'Find someone who has learned a new technology in the last 3 months.',
];

async function main() {
  const gameRef = db.collection('games').doc(gameId);
  await gameRef.set(
    {
      title: 'Namma Bingo',
      isActive: true,
      slotCount: QUESTIONS.length,
      startsAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const batch = db.batch();
  QUESTIONS.forEach((text, i) => {
    const order = i + 1;
    const ref = gameRef.collection('questions').doc(`q${order}`);
    batch.set(ref, { text, order, isActive: true }, { merge: true });
  });
  await batch.commit();

  console.log(`Seeded games/${gameId} + ${QUESTIONS.length} questions.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
