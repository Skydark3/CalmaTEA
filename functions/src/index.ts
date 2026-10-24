import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {
  generateTemporaryPassword,
  InvalidProvisionChildInputError,
  parseProvisionChildInput,
  ProvisionChildInput,
} from "./provision_child_input";

initializeApp();

const region = "southamerica-east1";
const usersCollection = "users";
const childrenCollection = "children";
const childAccountLinksCollection = "childAccountLinks";

export const provisionChildAccount = onCall(
  {region},
  async (request) => {
    if (request.auth === undefined) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const psychologistId = request.auth.uid;
    let input: ProvisionChildInput;
    try {
      input = parseProvisionChildInput(request.data);
    } catch (error) {
      if (error instanceof InvalidProvisionChildInputError) {
        throw new HttpsError("invalid-argument", "Invalid provisioning data.");
      }
      throw error;
    }

    const db = getFirestore();
    const callerProfile = await db
      .collection(usersCollection)
      .doc(psychologistId)
      .get();
    if (callerProfile.data()?.role !== "psychologist") {
      throw new HttpsError("permission-denied", "Operation not permitted.");
    }

    const childReference = db
      .collection(childrenCollection)
      .doc(input.childId);
    const childSnapshot = await childReference.get();
    const child = childSnapshot.data();
    if (
      !childSnapshot.exists ||
      child?.psychologistId !== psychologistId ||
      typeof child.fullName !== "string" ||
      child.fullName.trim().length === 0
    ) {
      throw new HttpsError("permission-denied", "Operation not permitted.");
    }

    const existingLink = await db
      .collection(usersCollection)
      .where("role", "==", "child")
      .where("childId", "==", input.childId)
      .limit(1)
      .get();
    if (!existingLink.empty) {
      throw new HttpsError("already-exists", "Patient access already exists.");
    }

    const reservationReference = db
      .collection(childAccountLinksCollection)
      .doc(input.childId);
    try {
      await db.runTransaction(async (transaction) => {
        const reservation = await transaction.get(reservationReference);
        if (reservation.exists) {
          throw new HttpsError(
            "already-exists",
            "Patient access already exists.",
          );
        }
        transaction.create(reservationReference, {
          childId: input.childId,
          psychologistId,
          status: "provisioning",
          createdAt: FieldValue.serverTimestamp(),
        });
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.error("Unable to reserve child account provisioning.", {
        psychologistId,
      });
      throw new HttpsError("internal", "Unable to provision patient access.");
    }

    let childAuthUid: string | undefined;
    try {
      const authUser = await getAuth().createUser({
        email: input.email,
        password: generateTemporaryPassword(),
        displayName: child.fullName.trim(),
      });
      childAuthUid = authUser.uid;

      const batch = db.batch();
      batch.create(db.collection(usersCollection).doc(childAuthUid), {
        id: childAuthUid,
        name: child.fullName.trim(),
        email: input.email,
        role: "child",
        childId: input.childId,
        createdAt: FieldValue.serverTimestamp(),
      });
      batch.set(
        reservationReference,
        {
          childAuthUid,
          status: "active",
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
      await batch.commit();

      logger.info("Child account provisioned.", {
        psychologistId,
        childAuthUid,
      });
      return {success: true, childAuthUid, email: input.email};
    } catch (error) {
      if (childAuthUid !== undefined) {
        try {
          await getAuth().deleteUser(childAuthUid);
        } catch (rollbackError) {
          logger.error("Unable to roll back orphaned Auth user.", {
            childAuthUid,
            rollbackError,
          });
        }
      }

      try {
        await reservationReference.delete();
      } catch (rollbackError) {
        logger.error("Unable to clear provisioning reservation.", {
          psychologistId,
          rollbackError,
        });
      }

      const errorCode = (error as {code?: string}).code;
      if (errorCode === "auth/email-already-exists") {
        throw new HttpsError("already-exists", "Email is already in use.");
      }
      logger.error("Child account provisioning failed.", {
        psychologistId,
        errorCode,
      });
      throw new HttpsError("internal", "Unable to provision patient access.");
    }
  },
);
