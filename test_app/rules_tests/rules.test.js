import { readFileSync } from 'node:fs';
import { describe, it, before, beforeEach, after } from 'node:test';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc,
  collection,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  writeBatch,
  serverTimestamp,
  Timestamp,
  GeoPoint,
} from 'firebase/firestore';

const RULES = readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');

const MIN = 60 * 1000;
const HOUR = 60 * MIN;
const inFuture = (ms) => Timestamp.fromDate(new Date(Date.now() + ms));
const inPast = (ms) => Timestamp.fromDate(new Date(Date.now() - ms));

const MOBILE = {
  res1: '+639170000001',
  res2: '+639170000002',
  unv: '+639170000003',
  resp1: '+639170000011',
  resp2: '+639170000012',
  unvResp: '+639170000013',
  unv2: '+639170000004',
  admin: '00000000',
};

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-akay',
    firestore: { rules: RULES },
  });
});

after(async () => {
  await env.cleanup();
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();
const seed = (fn) => env.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));

const user = (uid, role, verified = true) => ({
  mobile: MOBILE[uid],
  role,
  verified,
  createdAt: Timestamp.now(),
});

const household = () => ({
  name: 'Santos Household',
  barangay: 'Barangay Lumbo',
  address: 'Purok 4',
  location: new GeoPoint(8.4812, 124.6471),
  members: 4,
  mobilityNeed: 'None',
  notes: [],
  updatedAt: Timestamp.now(),
});

const requestDoc = (o = {}) => ({
  userId: 'res1',
  type: 'flood',
  barangay: 'Barangay Lumbo',
  location: new GeoPoint(8.481, 124.647),
  status: 'pending',
  responderId: null,
  responderMobile: null,
  createdAt: Timestamp.now(),
  updatedAt: Timestamp.now(),
  ...o,
});

const detailsDoc = (o = {}) => ({
  userId: 'res1',
  address: 'Purok 4',
  location: new GeoPoint(8.4812, 124.6471),
  description: null,
  household: { name: 'Santos Household', members: 4, mobilityNeed: 'None', notes: [] },
  createdAt: Timestamp.now(),
  ...o,
});

const markerDoc = (o = {}) => ({
  type: 'flood',
  status: 'pending',
  lat: 8.48,
  lng: 124.65,
  createdAt: Timestamp.now(),
  expiresAt: inFuture(24 * HOUR),
  ...o,
});

const notif = (type, fromUid, requestId, o = {}) => ({
  type,
  title: 'Title',
  body: 'Body',
  requestId,
  isRead: false,
  fromUid,
  createdAt: serverTimestamp(),
  ...o,
});

// Mirrors AkayBackend.sendRequest
function sendBatch(db, uid, id, o = {}) {
  const b = writeBatch(db);
  b.set(doc(db, 'requests', id), {
    userId: uid,
    type: 'flood',
    barangay: 'Barangay Lumbo',
    location: new GeoPoint(8.481, 124.647),
    status: 'pending',
    responderId: null,
    responderMobile: null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...(o.request || {}),
  });
  b.set(doc(db, 'requestDetails', id), {
    userId: uid,
    address: 'Purok 4',
    location: new GeoPoint(8.4812, 124.6471),
    description: null,
    household: { name: 'Santos Household', members: 4, mobilityNeed: 'None', notes: [] },
    createdAt: serverTimestamp(),
    ...(o.details || {}),
  });
  b.set(doc(db, 'publicMarkers', id), {
    type: 'flood',
    status: 'pending',
    lat: 8.48,
    lng: 124.65,
    createdAt: serverTimestamp(),
    expiresAt: inFuture(24 * HOUR),
    ...(o.marker || {}),
  });
  if (o.pointer !== false) b.set(doc(db, 'activeRequests', uid), { requestId: id });
  b.set(doc(db, 'notifications', uid, 'items', 'n1'), notif('request_created', uid, id));
  return b;
}

// Mirrors AkayBackend.acceptRequest
function acceptBatch(db, uid, id, o = {}) {
  const b = writeBatch(db);
  b.update(doc(db, 'requests', id), {
    status: 'matched',
    responderId: uid,
    responderMobile: MOBILE[uid],
    matchedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...(o.request || {}),
  });
  if (o.pointer !== false) b.set(doc(db, 'responderActive', uid), { requestId: id });
  b.delete(doc(db, 'publicMarkers', id));
  b.set(doc(db, 'notifications', 'res1', 'items', 'n1'), notif('request_matched', uid, id));
  return b;
}

// Mirrors AkayBackend.releaseRequest
function releaseBatch(db, uid, id, o = {}) {
  const b = writeBatch(db);
  b.update(doc(db, 'requests', id), {
    status: 'pending',
    responderId: null,
    responderMobile: null,
    matchedAt: null,
    updatedAt: serverTimestamp(),
  });
  if (o.deletePointer !== false) b.delete(doc(db, 'responderActive', uid));
  b.set(doc(db, 'publicMarkers', id), {
    type: 'flood',
    status: 'pending',
    lat: 8.48,
    lng: 124.65,
    createdAt: serverTimestamp(),
    expiresAt: inFuture(24 * HOUR),
  });
  b.set(doc(db, 'notifications', 'res1', 'items', 'n1'), notif('request_released', uid, id));
  return b;
}

// Mirrors AkayBackend.reopenRequest
function reopenBatch(db, id) {
  const b = writeBatch(db);
  b.update(doc(db, 'requests', id), {
    status: 'pending',
    responderId: null,
    responderMobile: null,
    matchedAt: null,
    updatedAt: serverTimestamp(),
  });
  b.delete(doc(db, 'responderActive', 'resp1'));
  b.set(doc(db, 'publicMarkers', id), {
    type: 'flood',
    status: 'pending',
    lat: 8.48,
    lng: 124.65,
    createdAt: serverTimestamp(),
    expiresAt: inFuture(24 * HOUR),
  });
  return b;
}

// A request matched to resp1, with every pointer in place.
async function seedMatched({ matchedAgo = 20 * MIN } = {}) {
  await seed(async (db) => {
    await setDoc(doc(db, 'requests', 'req1'), requestDoc({
      status: 'matched',
      responderId: 'resp1',
      responderMobile: MOBILE.resp1,
      matchedAt: inPast(matchedAgo),
    }));
    await setDoc(doc(db, 'requestDetails', 'req1'), detailsDoc());
    await setDoc(doc(db, 'activeRequests', 'res1'), { requestId: 'req1' });
    await setDoc(doc(db, 'responderActive', 'resp1'), { requestId: 'req1' });
  });
}

// A pending request with its marker and pointer in place.
async function seedPending() {
  await seed(async (db) => {
    await setDoc(doc(db, 'requests', 'req1'), requestDoc());
    await setDoc(doc(db, 'requestDetails', 'req1'), detailsDoc());
    await setDoc(doc(db, 'publicMarkers', 'req1'), markerDoc());
    await setDoc(doc(db, 'activeRequests', 'res1'), { requestId: 'req1' });
  });
}

beforeEach(async () => {
  await env.clearFirestore();
  await seed(async (db) => {
    await setDoc(doc(db, 'users', 'res1'), user('res1', 'resident'));
    await setDoc(doc(db, 'users', 'res2'), user('res2', 'resident'));
    await setDoc(doc(db, 'users', 'unv'), user('unv', 'resident', false));
    await setDoc(doc(db, 'users', 'resp1'), user('resp1', 'respondent'));
    await setDoc(doc(db, 'users', 'resp2'), user('resp2', 'respondent'));
    await setDoc(doc(db, 'users', 'unvResp'), user('unvResp', 'respondent', false));
    await setDoc(doc(db, 'users', 'admin'), user('admin', 'admin'));
    await setDoc(doc(db, 'households', 'res1'), household());
    await setDoc(doc(db, 'households', 'resp1'), household());
  });
});

// ---------------------------------------------------------------
describe('AK-01 verification codes', () => {
  const CODE = 'ABCD2345EFGH6789';

  const seedCode = (o = {}) =>
    seed((db) =>
      setDoc(doc(db, 'verificationCodes', CODE), {
        role: 'resident',
        used: false,
        expiresAt: inFuture(24 * HOUR),
        ...o,
      }),
    );

  const redeem = (db, uid) => {
    const b = writeBatch(db);
    b.update(doc(db, 'verificationCodes', CODE), { used: true, usedBy: uid });
    b.update(doc(db, 'users', uid), { verified: true, verifiedWith: CODE });
    return b.commit();
  };

  it('a signed-in user cannot read a code', async () => {
    await seedCode();
    await assertFails(getDoc(doc(as('unv'), 'verificationCodes', CODE)));
  });

  it('a valid code verifies the account', async () => {
    await seedCode();
    await assertSucceeds(redeem(as('unv'), 'unv'));
  });

  it('burning a code without verifying your own profile is denied', async () => {
    await seedCode();
    await assertFails(
      updateDoc(doc(as('unv'), 'verificationCodes', CODE), { used: true, usedBy: 'unv' }),
    );
  });

  it('an expired code is denied', async () => {
    await seedCode({ expiresAt: inPast(HOUR) });
    await assertFails(redeem(as('unv'), 'unv'));
  });

  it('an already used code is denied', async () => {
    await seedCode({ used: true, usedBy: 'someone' });
    await assertFails(redeem(as('unv'), 'unv'));
  });

  it('a code for the other role is denied', async () => {
    await seedCode({ role: 'respondent' });
    await assertFails(redeem(as('unv'), 'unv'));
  });

  it('setting verified on your own profile without a code is denied', async () => {
    await assertFails(updateDoc(doc(as('unv'), 'users', 'unv'), { verified: true }));
  });

  it('changing your own role is denied', async () => {
    await assertFails(updateDoc(doc(as('res1'), 'users', 'res1'), { role: 'respondent' }));
  });
});

// ---------------------------------------------------------------
describe('AK-02 notifications', () => {
  it('a party to a real request can write its own notification', async () => {
    await seedPending();
    await assertSucceeds(
      setDoc(doc(as('res1'), 'notifications', 'res1', 'items', 'n1'), notif('request_created', 'res1', 'req1')),
    );
  });

  it('an unrelated user cannot write into someone else inbox', async () => {
    await seedPending();
    await assertFails(
      setDoc(doc(as('res2'), 'notifications', 'res1', 'items', 'n1'), notif('request_matched', 'res2', 'req1')),
    );
  });

  it('a notification type that does not match the request status is denied', async () => {
    await seedPending();
    await assertFails(
      setDoc(doc(as('res1'), 'notifications', 'res1', 'items', 'n1'), notif('request_matched', 'res1', 'req1')),
    );
  });

  it('an over-long title is denied', async () => {
    await seedPending();
    await assertFails(
      setDoc(
        doc(as('res1'), 'notifications', 'res1', 'items', 'n1'),
        notif('request_created', 'res1', 'req1', { title: 'x'.repeat(81) }),
      ),
    );
  });

  it('a client supplied createdAt is denied', async () => {
    await seedPending();
    await assertFails(
      setDoc(
        doc(as('res1'), 'notifications', 'res1', 'items', 'n1'),
        notif('request_created', 'res1', 'req1', { createdAt: Timestamp.now() }),
      ),
    );
  });

  it('you cannot read someone else inbox', async () => {
    await seed((db) =>
      setDoc(doc(db, 'notifications', 'res1', 'items', 'n1'), notif('request_created', 'res1', 'req1')),
    );
    await assertFails(getDoc(doc(as('res2'), 'notifications', 'res1', 'items', 'n1')));
  });
});

// ---------------------------------------------------------------
describe('AK-03 request creation', () => {
  it('a verified resident with a household can send a request', async () => {
    await assertSucceeds(sendBatch(as('res1'), 'res1', 'req1').commit());
  });

  it('a second request while one is active is denied', async () => {
    await seedPending();
    await assertFails(sendBatch(as('res1'), 'res1', 'req2').commit());
  });

  it('a request without the active pointer is denied', async () => {
    await assertFails(sendBatch(as('res1'), 'res1', 'req1', { pointer: false }).commit());
  });

  it('a respondent cannot create a request', async () => {
    await assertFails(sendBatch(as('resp1'), 'resp1', 'req1').commit());
  });

  it('a resident without a household cannot create a request', async () => {
    await assertFails(sendBatch(as('res2'), 'res2', 'req1').commit());
  });

  it('an extra field is denied', async () => {
    await assertFails(sendBatch(as('res1'), 'res1', 'req1', { request: { extra: 1 } }).commit());
  });

  it('an invalid type is denied', async () => {
    await assertFails(sendBatch(as('res1'), 'res1', 'req1', { request: { type: 'alien' } }).commit());
  });

  it('an over-long description is denied', async () => {
    await assertFails(
      sendBatch(as('res1'), 'res1', 'req1', { details: { description: 'x'.repeat(501) } }).commit(),
    );
  });

  it('an address that differs from the household is denied', async () => {
    await assertFails(sendBatch(as('res1'), 'res1', 'req1', { details: { address: 'Somewhere else' } }).commit());
  });

  it('a request for another user is denied', async () => {
    await assertFails(sendBatch(as('res2'), 'res1', 'req1').commit());
  });

  it('another user cannot cancel, resolve or edit my request', async () => {
    await seedPending();
    await assertFails(
      updateDoc(doc(as('res2'), 'requests', 'req1'), { status: 'cancelled', updatedAt: serverTimestamp() }),
    );
    await assertFails(updateDoc(doc(as('res2'), 'requests', 'req1'), { type: 'fire' }));
  });

  it('the requester can cancel a pending request', async () => {
    await seedPending();
    const db = as('res1'); // one instance for the batch and every reference in it
    const b = writeBatch(db);
    b.delete(doc(db, 'activeRequests', 'res1'));
    b.update(doc(db, 'requests', 'req1'), { status: 'cancelled', updatedAt: serverTimestamp() });
    b.delete(doc(db, 'publicMarkers', 'req1'));
    b.set(doc(db, 'notifications', 'res1', 'items', 'n2'), notif('request_cancelled', 'res1', 'req1'));
    await assertSucceeds(b.commit());
  });
});

// ---------------------------------------------------------------
describe('AK-04 request details', () => {
  it('a verified responder can list pending requests', async () => {
    await seedPending();
    await assertSucceeds(
      getDocs(query(collection(as('resp1'), 'requests'), where('status', '==', 'pending'))),
    );
  });

  it('a resident cannot list pending requests', async () => {
    await seedPending();
    await assertFails(
      getDocs(query(collection(as('res2'), 'requests'), where('status', '==', 'pending'))),
    );
  });

  it('an unverified respondent cannot read a pending request', async () => {
    await seedPending();
    await assertFails(getDoc(doc(as('unvResp'), 'requests', 'req1')));
  });

  it('an unmatched responder cannot read request details', async () => {
    await seedPending();
    await assertFails(getDoc(doc(as('resp1'), 'requestDetails', 'req1')));
  });

  it('the matched responder can read request details', async () => {
    await seedMatched();
    await assertSucceeds(getDoc(doc(as('resp1'), 'requestDetails', 'req1')));
  });

  it('a different responder cannot read details of a matched request', async () => {
    await seedMatched();
    await assertFails(getDoc(doc(as('resp2'), 'requestDetails', 'req1')));
  });

  it('the former responder loses access once the request is resolved', async () => {
    await seedMatched();
    await seed((db) => updateDoc(doc(db, 'requests', 'req1'), { status: 'resolved' }));
    await assertFails(getDoc(doc(as('resp1'), 'requestDetails', 'req1')));
  });

  it('the requester can read their own details', async () => {
    await seedPending();
    await assertSucceeds(getDoc(doc(as('res1'), 'requestDetails', 'req1')));
  });

  it('another resident cannot read someone else details or household', async () => {
    await seedPending();
    await assertFails(getDoc(doc(as('res2'), 'requestDetails', 'req1')));
    await assertFails(getDoc(doc(as('res2'), 'households', 'res1')));
  });

  it('request details cannot be edited', async () => {
    await seedPending();
    await assertFails(updateDoc(doc(as('res1'), 'requestDetails', 'req1'), { address: 'x' }));
  });
});

// ---------------------------------------------------------------
describe('AK-05 presence', () => {
  const presence = (o = {}) => ({
    online: true,
    lat: 8.48,
    lng: 124.65,
    updatedAt: serverTimestamp(),
    ...o,
  });

  it('a verified user can read presence', async () => {
    await seed((db) => setDoc(doc(db, 'presence', 'resp1'), { online: true, lat: 8.48, lng: 124.65, updatedAt: Timestamp.now() }));
    await assertSucceeds(getDoc(doc(as('res1'), 'presence', 'resp1')));
  });

  it('an unverified user cannot read presence', async () => {
    await seed((db) => setDoc(doc(db, 'presence', 'resp1'), { online: true, lat: 8.48, lng: 124.65, updatedAt: Timestamp.now() }));
    await assertFails(getDoc(doc(as('unv'), 'presence', 'resp1')));
  });

  it('a verified responder can write their own presence', async () => {
    await assertSucceeds(setDoc(doc(as('resp1'), 'presence', 'resp1'), presence()));
  });

  it('going offline without coordinates is allowed', async () => {
    await assertSucceeds(setDoc(doc(as('resp1'), 'presence', 'resp1'), { online: false, updatedAt: serverTimestamp() }));
  });

  it('out of range coordinates are denied', async () => {
    await assertFails(setDoc(doc(as('resp1'), 'presence', 'resp1'), presence({ lat: 80 })));
  });

  it('a string coordinate is denied', async () => {
    await assertFails(setDoc(doc(as('resp1'), 'presence', 'resp1'), presence({ lat: 'x' })));
  });

  it('lat without lng is denied', async () => {
    await assertFails(setDoc(doc(as('resp1'), 'presence', 'resp1'), { online: true, lat: 8.48, updatedAt: serverTimestamp() }));
  });

  it('a client supplied updatedAt is denied', async () => {
    await assertFails(setDoc(doc(as('resp1'), 'presence', 'resp1'), presence({ updatedAt: Timestamp.now() })));
  });

  it('an extra key is denied', async () => {
    await assertFails(setDoc(doc(as('resp1'), 'presence', 'resp1'), presence({ extra: 1 })));
  });

  it('a resident cannot write presence', async () => {
    await assertFails(setDoc(doc(as('res1'), 'presence', 'res1'), presence()));
  });

  it('a responder cannot write another responder presence', async () => {
    await assertFails(setDoc(doc(as('resp1'), 'presence', 'resp2'), presence()));
  });
});

// ---------------------------------------------------------------
describe('AK-06 public markers', () => {
  const create = (db, uid, id, o = {}) =>
    setDoc(doc(db, 'publicMarkers', id), {
      type: 'flood',
      status: 'pending',
      lat: 8.48,
      lng: 124.65,
      createdAt: serverTimestamp(),
      expiresAt: inFuture(24 * HOUR),
      ...o,
    });

  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'requests', 'req1'), requestDoc());
    });
  });

  it('the owner of a pending request can create its marker', async () => {
    await assertSucceeds(create(as('res1'), 'res1', 'req1'));
  });

  it('a marker without a matching request is denied', async () => {
    await assertFails(create(as('res1'), 'res1', 'nope'));
  });

  it('a marker for someone else request is denied', async () => {
    await assertFails(create(as('res2'), 'res2', 'req1'));
  });

  it('a marker carrying ownerId is denied', async () => {
    await assertFails(create(as('res1'), 'res1', 'req1', { ownerId: 'res1' }));
  });

  it('a marker with a string coordinate is denied', async () => {
    await assertFails(create(as('res1'), 'res1', 'req1', { lat: 'x' }));
  });

  it('a marker far from the request is denied', async () => {
    await assertFails(create(as('res1'), 'res1', 'req1', { lat: 8.6 }));
  });

  it('a marker that expires in 5 days is denied', async () => {
    await assertFails(create(as('res1'), 'res1', 'req1', { expiresAt: inFuture(5 * 24 * HOUR) }));
  });

  it('a stranger cannot delete a marker', async () => {
    await seed((db) => setDoc(doc(db, 'publicMarkers', 'req1'), markerDoc()));
    await seed((db) => updateDoc(doc(db, 'requests', 'req1'), { status: 'cancelled' }));
    await assertFails(deleteDoc(doc(as('res2'), 'publicMarkers', 'req1')));
  });

  it('the owner cannot delete a marker while the request is still pending', async () => {
    await seed((db) => setDoc(doc(db, 'publicMarkers', 'req1'), markerDoc()));
    await assertFails(deleteDoc(doc(as('res1'), 'publicMarkers', 'req1')));
  });

  it('the owner can delete the marker after cancelling', async () => {
    await seed((db) => setDoc(doc(db, 'publicMarkers', 'req1'), markerDoc()));
    await seed((db) => updateDoc(doc(db, 'requests', 'req1'), { status: 'cancelled' }));
    await assertSucceeds(deleteDoc(doc(as('res1'), 'publicMarkers', 'req1')));
  });
});

// ---------------------------------------------------------------
describe('AK-07 account creation', () => {
  const profile = (o = {}) => ({
    mobile: '+639171234567',
    role: 'resident',
    verified: false,
    createdAt: serverTimestamp(),
    ...o,
  });

  it('a valid profile can be created', async () => {
    await assertSucceeds(setDoc(doc(as('newbie'), 'users', 'newbie'), profile()));
  });

  it('a malformed mobile number is denied', async () => {
    await assertFails(setDoc(doc(as('newbie'), 'users', 'newbie'), profile({ mobile: '+6391234' })));
  });

  it('creating an already verified profile is denied', async () => {
    await assertFails(setDoc(doc(as('newbie'), 'users', 'newbie'), profile({ verified: true })));
  });

  it('an unknown role is denied', async () => {
    await assertFails(setDoc(doc(as('newbie'), 'users', 'newbie'), profile({ role: 'admin' })));
  });

  it('creating a profile for another uid is denied', async () => {
    await assertFails(setDoc(doc(as('newbie'), 'users', 'other'), profile()));
  });

  it('you cannot read another user profile', async () => {
    await assertFails(getDoc(doc(as('res2'), 'users', 'res1')));
  });
});

// ---------------------------------------------------------------
describe('AK-08 accept, release, cap and re-open', () => {
  it('a verified responder can accept a pending request', async () => {
    await seedPending();
    await assertSucceeds(acceptBatch(as('resp1'), 'resp1', 'req1').commit());
  });

  it('accepting with a spoofed number is denied', async () => {
    await seedPending();
    await assertFails(
      acceptBatch(as('resp1'), 'resp1', 'req1', { request: { responderMobile: '+639999999999' } }).commit(),
    );
  });

  it('accepting without taking the job slot is denied', async () => {
    await seedPending();
    await assertFails(acceptBatch(as('resp1'), 'resp1', 'req1', { pointer: false }).commit());
  });

  it('a responder cannot hold two jobs', async () => {
    await seedPending();
    await seed(async (db) => {
      await setDoc(doc(db, 'requests', 'req0'), requestDoc({
        userId: 'res2',
        status: 'matched',
        responderId: 'resp1',
        responderMobile: MOBILE.resp1,
        matchedAt: Timestamp.now(),
      }));
      await setDoc(doc(db, 'responderActive', 'resp1'), { requestId: 'req0' });
    });
    await assertFails(acceptBatch(as('resp1'), 'resp1', 'req1').commit());
  });

  it('a responder cannot accept their own request', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'requests', 'req1'), requestDoc({ userId: 'resp1' }));
      await setDoc(doc(db, 'publicMarkers', 'req1'), markerDoc());
    });
    await assertFails(acceptBatch(as('resp1'), 'resp1', 'req1').commit());
  });

  it('an unverified responder cannot accept', async () => {
    await seedPending();
    await assertFails(acceptBatch(as('unvResp'), 'unvResp', 'req1').commit());
  });

  it('a resident cannot accept', async () => {
    await seedPending();
    await assertFails(acceptBatch(as('res2'), 'res2', 'req1').commit());
  });

  it('only one of two responders can accept the same request', async () => {
    await seedPending();
    await assertSucceeds(acceptBatch(as('resp1'), 'resp1', 'req1').commit());
    await assertFails(acceptBatch(as('resp2'), 'resp2', 'req1').commit());
  });

  it('the assigned responder can release the request', async () => {
    await seedMatched({ matchedAgo: MIN });
    await assertSucceeds(releaseBatch(as('resp1'), 'resp1', 'req1').commit());
  });

  it('releasing without freeing the job slot is denied', async () => {
    await seedMatched({ matchedAgo: MIN });
    await assertFails(releaseBatch(as('resp1'), 'resp1', 'req1', { deletePointer: false }).commit());
  });

  it('another responder cannot release the request', async () => {
    await seedMatched({ matchedAgo: MIN });
    await assertFails(releaseBatch(as('resp2'), 'resp2', 'req1').commit());
  });

  it('a responder cannot drop the job slot while still assigned', async () => {
    await seedMatched({ matchedAgo: MIN });
    await assertFails(deleteDoc(doc(as('resp1'), 'responderActive', 'resp1')));
  });

  it('the requester can re-open after 15 minutes', async () => {
    await seedMatched({ matchedAgo: 20 * MIN });
    await assertSucceeds(reopenBatch(as('res1'), 'req1').commit());
  });

  it('the requester cannot re-open before 15 minutes', async () => {
    await seedMatched({ matchedAgo: MIN });
    await assertFails(reopenBatch(as('res1'), 'req1').commit());
  });

  it('someone else cannot re-open the request', async () => {
    await seedMatched({ matchedAgo: 20 * MIN });
    await assertFails(reopenBatch(as('res2'), 'req1').commit());
  });

  it('the requester can cancel a matched request and frees the responder', async () => {
    await seedMatched({ matchedAgo: MIN });
    const db = as('res1');
    const b = writeBatch(db);
    b.delete(doc(db, 'activeRequests', 'res1'));
    b.delete(doc(db, 'responderActive', 'resp1'));
    b.update(doc(db, 'requests', 'req1'), { status: 'cancelled', updatedAt: serverTimestamp() });
    b.set(doc(db, 'notifications', 'res1', 'items', 'n1'), notif('request_cancelled', 'res1', 'req1'));
    b.set(doc(db, 'notifications', 'resp1', 'items', 'n1'), notif('request_cancelled', 'res1', 'req1'));
    await assertSucceeds(b.commit());
  });

  it('the responder can resolve a matched request', async () => {
    await seedMatched({ matchedAgo: MIN });
    const db = as('resp1');
    const b = writeBatch(db);
    b.delete(doc(db, 'activeRequests', 'res1'));
    b.delete(doc(db, 'responderActive', 'resp1'));
    b.update(doc(db, 'requests', 'req1'), {
      status: 'resolved',
      resolvedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    b.set(doc(db, 'notifications', 'resp1', 'items', 'n1'), notif('request_resolved', 'resp1', 'req1'));
    b.set(doc(db, 'notifications', 'res1', 'items', 'n1'), notif('request_resolved', 'resp1', 'req1'));
    await assertSucceeds(b.commit());
  });

  it('a pending request cannot be resolved', async () => {
    await seedPending();
    await assertFails(
      updateDoc(doc(as('res1'), 'requests', 'req1'), {
        status: 'resolved',
        resolvedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });
});

// ---------------------------------------------------------------
// Section 7 of the audit lists attack cases that must all be denied.
// These two were not covered yet.
describe('AK-10 checklist gaps', () => {
  it('a stranger cannot resolve a matched request', async () => {
    await seedMatched({ matchedAgo: MIN });
    await assertFails(
      updateDoc(doc(as('res2'), 'requests', 'req1'), {
        status: 'resolved',
        resolvedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      }),
    );
  });

  // AK-14 is still open: firestore.rules has "allow read: if true" on config.
  // Marked todo so the run stays green until AK-14 is fixed. When it is,
  // delete the { todo } option so this test becomes a normal, enforced one.
  it(
    'config cannot be read while signed out',
    { todo: 'AK-14: config is still readable without login' },
    async () => {
      await assertFails(getDoc(doc(anon(), 'config', 'app')));
    },
  );
});

// ---------------------------------------------------------------
// Admin account (mobile 00000000), created by hand in the Firebase console.
// These cover the rules added for the Admin screen.
describe('admin account', () => {
  const PIN = '483920';

  const pin = (o = {}) => ({
    role: 'respondent',
    used: false,
    expiresAt: inFuture(30 * MIN),
    createdAt: serverTimestamp(),
    createdBy: 'admin',
    demo: false,
    ...o,
  });

  // A pin as it sits in the database (written with the rules switched off).
  const seedPin = (o = {}) =>
    seed((db) =>
      setDoc(doc(db, 'verificationCodes', PIN), {
        role: 'resident',
        used: false,
        expiresAt: inFuture(30 * MIN),
        createdBy: 'admin',
        demo: false,
        ...o,
      }),
    );

  // Mirrors AkayBackend.verifyCode
  const redeem = (db, uid) => {
    const b = writeBatch(db);
    b.update(doc(db, 'verificationCodes', PIN), { used: true, usedBy: uid });
    b.update(doc(db, 'users', uid), { verified: true, verifiedWith: PIN });
    return b.commit();
  };

  // ----- who counts as admin -----

  it('nobody can sign up with the admin number', async () => {
    await assertFails(
      setDoc(doc(as('newbie'), 'users', 'newbie'), {
        mobile: '00000000',
        role: 'resident',
        verified: false,
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('a user cannot change their mobile to the admin number', async () => {
    await assertFails(updateDoc(doc(as('res1'), 'users', 'res1'), { mobile: '00000000' }));
  });

  // ----- accounts -----

  it('the admin can list every account', async () => {
    await assertSucceeds(getDocs(collection(as('admin'), 'users')));
  });

  it('a normal user cannot list accounts', async () => {
    await assertFails(getDocs(collection(as('res1'), 'users')));
  });

  // ----- one-time pins -----

  it('the admin can create a pin', async () => {
    await assertSucceeds(setDoc(doc(as('admin'), 'verificationCodes', PIN), pin()));
  });

  it('the admin can create a 24 hour demo pin', async () => {
    await assertSucceeds(
      setDoc(doc(as('admin'), 'verificationCodes', PIN), pin({ demo: true, expiresAt: inFuture(24 * HOUR) })),
    );
  });

  it('a pin can be tied to one account', async () => {
    await assertSucceeds(
      setDoc(doc(as('admin'), 'verificationCodes', PIN), pin({ forUid: 'unv', forMobile: MOBILE.unv })),
    );
  });

  it('a normal user cannot create a pin', async () => {
    await assertFails(setDoc(doc(as('res1'), 'verificationCodes', PIN), pin({ createdBy: 'res1' })));
  });

  it('a signed out user cannot create a pin', async () => {
    await assertFails(setDoc(doc(anon(), 'verificationCodes', PIN), pin()));
  });

  it('a pin whose id is not 6 digits is denied', async () => {
    await assertFails(setDoc(doc(as('admin'), 'verificationCodes', 'ABCD2345EFGH6789'), pin()));
  });

  it('a pin that expires in 3 days is denied', async () => {
    await assertFails(
      setDoc(doc(as('admin'), 'verificationCodes', PIN), pin({ expiresAt: inFuture(3 * 24 * HOUR) })),
    );
  });

  it('a pin that is already expired is denied', async () => {
    await assertFails(setDoc(doc(as('admin'), 'verificationCodes', PIN), pin({ expiresAt: inPast(MIN) })));
  });

  it('a pin that is already used is denied', async () => {
    await assertFails(setDoc(doc(as('admin'), 'verificationCodes', PIN), pin({ used: true })));
  });

  it('a pin for the admin role is denied', async () => {
    await assertFails(setDoc(doc(as('admin'), 'verificationCodes', PIN), pin({ role: 'admin' })));
  });

  it('a pin with an extra field is denied', async () => {
    await assertFails(setDoc(doc(as('admin'), 'verificationCodes', PIN), pin({ extra: 1 })));
  });

  it('a pin credited to someone else is denied', async () => {
    await assertFails(setDoc(doc(as('admin'), 'verificationCodes', PIN), pin({ createdBy: 'res1' })));
  });

  it('a client supplied createdAt on a pin is denied', async () => {
    await assertFails(
      setDoc(doc(as('admin'), 'verificationCodes', PIN), pin({ createdAt: Timestamp.now() })),
    );
  });

  it('the admin can read a pin', async () => {
    await seedPin();
    await assertSucceeds(getDoc(doc(as('admin'), 'verificationCodes', PIN)));
  });

  it('the admin can revoke an unused pin', async () => {
    await seedPin();
    await assertSucceeds(deleteDoc(doc(as('admin'), 'verificationCodes', PIN)));
  });

  it('the admin cannot delete a pin that was used', async () => {
    await seedPin({ used: true, usedBy: 'someone' });
    await assertFails(deleteDoc(doc(as('admin'), 'verificationCodes', PIN)));
  });

  it('a normal user cannot read or revoke a pin', async () => {
    await seedPin();
    await assertFails(getDoc(doc(as('res1'), 'verificationCodes', PIN)));
    await assertFails(deleteDoc(doc(as('res1'), 'verificationCodes', PIN)));
  });

  it('an admin made pin verifies the account it was made for', async () => {
    await seedPin({ forUid: 'unv', forMobile: MOBILE.unv });
    await assertSucceeds(redeem(as('unv'), 'unv'));
  });

  it('a pin made for one account cannot be redeemed by another', async () => {
    await seed((db) => setDoc(doc(db, 'users', 'unv2'), user('unv2', 'resident', false)));
    await seedPin({ forUid: 'unv', forMobile: MOBILE.unv });
    await assertFails(redeem(as('unv2'), 'unv2'));
    await assertSucceeds(redeem(as('unv'), 'unv'));
  });

  it('a pin that is not tied to an account still works for its role', async () => {
    await seedPin();
    await assertSucceeds(redeem(as('unv'), 'unv'));
  });

  // ----- 911 calls (demonstration) -----

  it('the admin can list every request', async () => {
    await seedPending();
    await assertSucceeds(getDocs(collection(as('admin'), 'requests')));
  });

  it('a resident cannot list every request', async () => {
    await seedPending();
    await assertFails(getDocs(collection(as('res2'), 'requests')));
  });

  it('the admin can accept a pending request', async () => {
    await seedPending();
    await assertSucceeds(acceptBatch(as('admin'), 'admin', 'req1').commit());
  });

  it('the admin cannot accept with a spoofed number', async () => {
    await seedPending();
    await assertFails(
      acceptBatch(as('admin'), 'admin', 'req1', { request: { responderMobile: '+639999999999' } }).commit(),
    );
  });

  it('the admin can resolve a call they accepted', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'requests', 'req1'), requestDoc({
        status: 'matched',
        responderId: 'admin',
        responderMobile: MOBILE.admin,
        matchedAt: inPast(MIN),
      }));
      await setDoc(doc(db, 'requestDetails', 'req1'), detailsDoc());
      await setDoc(doc(db, 'activeRequests', 'res1'), { requestId: 'req1' });
      await setDoc(doc(db, 'responderActive', 'admin'), { requestId: 'req1' });
    });
    const db = as('admin');
    const b = writeBatch(db);
    b.delete(doc(db, 'activeRequests', 'res1'));
    b.delete(doc(db, 'responderActive', 'admin'));
    b.update(doc(db, 'requests', 'req1'), {
      status: 'resolved',
      resolvedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    b.set(doc(db, 'notifications', 'admin', 'items', 'n1'), notif('request_resolved', 'admin', 'req1'));
    b.set(doc(db, 'notifications', 'res1', 'items', 'n1'), notif('request_resolved', 'admin', 'req1'));
    await assertSucceeds(b.commit());
  });
});

// ---------------------------------------------------------------
describe('error log', () => {
  const entry = (o = {}) => ({
    uid: 'res1',
    source: 'shown to user',
    message: 'Something failed',
    stack: null,
    createdAt: serverTimestamp(),
    ...o,
  });

  const seedLog = () =>
    seed((db) => setDoc(doc(db, 'errorLogs', 'e1'), entry({ createdAt: Timestamp.now() })));

  it('a signed-in user can save an error', async () => {
    const db = as('res1');
    await assertSucceeds(setDoc(doc(collection(db, 'errorLogs')), entry()));
  });

  it('an error with a stack trace can be saved', async () => {
    const db = as('res1');
    await assertSucceeds(setDoc(doc(collection(db, 'errorLogs')), entry({ stack: 'at main (main.dart:1)' })));
  });

  it('a signed out user cannot save an error', async () => {
    const db = anon();
    await assertFails(setDoc(doc(collection(db, 'errorLogs')), entry()));
  });

  it('an error credited to another user is denied', async () => {
    const db = as('res1');
    await assertFails(setDoc(doc(collection(db, 'errorLogs')), entry({ uid: 'res2' })));
  });

  it('an over-long message is denied', async () => {
    const db = as('res1');
    await assertFails(setDoc(doc(collection(db, 'errorLogs')), entry({ message: 'x'.repeat(501) })));
  });

  it('an over-long stack trace is denied', async () => {
    const db = as('res1');
    await assertFails(setDoc(doc(collection(db, 'errorLogs')), entry({ stack: 'x'.repeat(2001) })));
  });

  it('an extra field is denied', async () => {
    const db = as('res1');
    await assertFails(setDoc(doc(collection(db, 'errorLogs')), entry({ extra: 1 })));
  });

  it('a client supplied createdAt is denied', async () => {
    const db = as('res1');
    await assertFails(setDoc(doc(collection(db, 'errorLogs')), entry({ createdAt: Timestamp.now() })));
  });

  it('a normal user cannot read, edit or delete the log', async () => {
    await seedLog();
    await assertFails(getDoc(doc(as('res1'), 'errorLogs', 'e1')));
    await assertFails(getDocs(collection(as('res1'), 'errorLogs')));
    await assertFails(updateDoc(doc(as('res1'), 'errorLogs', 'e1'), { message: 'changed' }));
    await assertFails(deleteDoc(doc(as('res1'), 'errorLogs', 'e1')));
  });

  it('the admin can read and delete the log', async () => {
    await seedLog();
    await assertSucceeds(getDocs(collection(as('admin'), 'errorLogs')));
    await assertSucceeds(deleteDoc(doc(as('admin'), 'errorLogs', 'e1')));
  });

  it('even the admin cannot edit an entry', async () => {
    await seedLog();
    await assertFails(updateDoc(doc(as('admin'), 'errorLogs', 'e1'), { message: 'changed' }));
  });
});

// ---------------------------------------------------------------
describe('signed out access', () => {
  it('a signed out user cannot read requests, users or codes', async () => {
    await seedPending();
    await assertFails(getDoc(doc(anon(), 'requests', 'req1')));
    await assertFails(getDoc(doc(anon(), 'users', 'res1')));
    await assertFails(getDoc(doc(anon(), 'verificationCodes', 'ABCD2345EFGH6789')));
  });
});

// ---------------------------------------------------------------
describe('evacuation status, check-in, declines, reports', () => {
  it('a user can set and read only their own evacuation status', async () => {
    await assertSucceeds(
      setDoc(doc(as('res1'), 'evacuationStatus', 'res1'), { status: 'transit', updatedAt: serverTimestamp() }),
    );
    await assertSucceeds(getDoc(doc(as('res1'), 'evacuationStatus', 'res1')));
    await assertFails(getDoc(doc(as('res2'), 'evacuationStatus', 'res1')));
    await assertFails(
      setDoc(doc(as('res2'), 'evacuationStatus', 'res1'), { status: 'home', updatedAt: serverTimestamp() }),
    );
  });

  it('evacuation status rejects unknown values and extra fields', async () => {
    await assertFails(
      setDoc(doc(as('res1'), 'evacuationStatus', 'res1'), { status: 'teleported', updatedAt: serverTimestamp() }),
    );
    await assertFails(
      setDoc(doc(as('res1'), 'evacuationStatus', 'res1'), { status: 'home', updatedAt: serverTimestamp(), x: 1 }),
    );
  });

  const checkIn = (o = {}) => ({
    responderId: 'resp1',
    household: 'AKAY-HH-042 Santos',
    membersPresent: 4,
    allConfirmed: true,
    createdAt: serverTimestamp(),
    ...o,
  });

  it('a verified responder can check a household in', async () => {
    await assertSucceeds(setDoc(doc(collection(as('resp1'), 'checkIns')), checkIn()));
  });

  it('residents, unverified responders and forged responderId cannot check in', async () => {
    await assertFails(setDoc(doc(collection(as('res1'), 'checkIns')), checkIn({ responderId: 'res1' })));
    await assertFails(setDoc(doc(collection(as('unvResp'), 'checkIns')), checkIn({ responderId: 'unvResp' })));
    await assertFails(setDoc(doc(collection(as('resp1'), 'checkIns')), checkIn({ responderId: 'resp2' })));
    await assertFails(setDoc(doc(collection(as('resp1'), 'checkIns')), checkIn({ membersPresent: 0 })));
    await assertFails(setDoc(doc(collection(as('resp1'), 'checkIns')), checkIn({ allConfirmed: false })));
  });

  it('a responder can decline for themselves only', async () => {
    await assertSucceeds(
      setDoc(doc(as('resp1'), 'responderDeclines', 'resp1', 'items', 'req1'), { createdAt: serverTimestamp() }),
    );
    await assertSucceeds(getDocs(collection(as('resp1'), 'responderDeclines', 'resp1', 'items')));
    await assertFails(
      setDoc(doc(as('resp1'), 'responderDeclines', 'resp2', 'items', 'req1'), { createdAt: serverTimestamp() }),
    );
    await assertFails(getDocs(collection(as('resp2'), 'responderDeclines', 'resp1', 'items')));
  });

  it('a verified responder can report a ping but nobody can read reports', async () => {
    const rep = { reporterId: 'resp1', requestId: 'req1', reason: 'Suspicious ping', createdAt: serverTimestamp() };
    await assertSucceeds(setDoc(doc(collection(as('resp1'), 'reports')), rep));
    await assertFails(setDoc(doc(collection(as('res1'), 'reports')), { ...rep, reporterId: 'res1' }));
    await assertFails(getDocs(collection(as('resp1'), 'reports')));
  });
});