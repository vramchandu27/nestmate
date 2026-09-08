/**
 * Push-notification triggers for NestMate. The Flutter app never sends
 * pushes itself — it only registers this device's token (see
 * lib/services/push_notification_service.dart, which writes
 * buildings/main/flats/{flatNumber}.fcmToken for a resident, or
 * buildings/main.adminFcmToken for the admin). These functions watch for
 * the four events that should notify someone, and do the actual sending.
 */

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

/** Sends one push; a missing/failed token never throws past this point —
 * a notification is an enhancement, never something that should surface
 * as a Firestore-write failure to whoever triggered it. */
async function sendPush(
  token: string | undefined,
  title: string,
  body: string,
  type: string
): Promise<void> {
  if (!token) return;
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data: { type },
    });
  } catch (err) {
    logger.error(`Failed to send "${type}" push`, err);
  }
}

async function adminToken(): Promise<string | undefined> {
  const buildingDoc = await db.doc("buildings/main").get();
  return buildingDoc.data()?.adminFcmToken as string | undefined;
}

async function flatToken(flatNumber: string): Promise<string | undefined> {
  const flatDoc = await db.doc(`buildings/main/flats/${flatNumber}`).get();
  return flatDoc.data()?.fcmToken as string | undefined;
}

// 1. New community notice → every resident with a registered token.
export const onNoticePosted = onDocumentCreated(
  "buildings/main/posts/{postId}",
  async (event) => {
    const post = event.data?.data();
    if (!post) return;
    const flatsSnap = await db.collection("buildings/main/flats").get();
    const title = typeof post.title === "string" && post.title.length > 0
      ? post.title
      : "New notice";
    await Promise.all(
      flatsSnap.docs.map((doc) =>
        sendPush(
          doc.data().fcmToken as string | undefined,
          title,
          "Admin posted a new notice. Tap to view.",
          "new_notice"
        )
      )
    );
  }
);

// 2. Admin confirms a payment → that flat's resident.
export const onBillConfirmed = onDocumentUpdated(
  "buildings/main/months/{monthId}/bills/{flatNumber}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === "confirmed" || after.status !== "confirmed") return;

    const token = await flatToken(event.params.flatNumber);
    await sendPush(
      token,
      "Payment confirmed",
      "Your payment has been confirmed by the admin.",
      "payment_confirmed"
    );
  }
);

// 3. Resident reports a new issue → the admin.
export const onIssueReported = onDocumentCreated(
  "buildings/main/issues/{issueId}",
  async (event) => {
    const issue = event.data?.data();
    if (!issue) return;
    const token = await adminToken();
    const flatNumber = issue.flatNumber ?? "?";
    const title =
      typeof issue.title === "string" && issue.title.length > 0
        ? `Flat ${flatNumber}: ${issue.title}`
        : `New issue reported — flat ${flatNumber}`;
    await sendPush(token, "New issue reported", title, "new_issue");
  }
);

// 4. Resident uploads a payment screenshot → the admin (awaiting confirmation).
export const onScreenshotUploaded = onDocumentUpdated(
  "buildings/main/months/{monthId}/bills/{flatNumber}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (
      before.status === "screenshotUploaded" ||
      after.status !== "screenshotUploaded"
    ) {
      return;
    }

    const token = await adminToken();
    await sendPush(
      token,
      "Payment screenshot uploaded",
      `Flat ${event.params.flatNumber} uploaded a payment screenshot, awaiting confirmation.`,
      "screenshot_uploaded"
    );
  }
);
