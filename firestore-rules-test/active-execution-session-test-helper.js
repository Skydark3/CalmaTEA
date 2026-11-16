const { doc, serverTimestamp } = require("firebase/firestore");

function createSessionWithLock(
  transaction,
  db,
  sessionReference,
  sessionData,
) {
  transaction.set(sessionReference, sessionData);
  transaction.set(
    doc(db, "activeExecutionSessions", sessionData.childId),
    {
      sessionId: sessionReference.id,
      activityId: sessionData.activityId,
      childId: sessionData.childId,
      psychologistId: sessionData.psychologistId,
      childUserId: sessionData.childUserId,
      startedAt: serverTimestamp(),
    },
  );
}

function releaseSessionLock(transaction, db, childId) {
  transaction.delete(doc(db, "activeExecutionSessions", childId));
}

module.exports = { createSessionWithLock, releaseSessionLock };
