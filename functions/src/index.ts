/**
 * Push-notification triggers for Resko. The Flutter app never sends pushes
 * itself — it only registers this device's token (see
 * lib/services/push_notification_service.dart, which writes
 * buildings/{buildingId}/flats/{flatNumber}.fcmToken for a resident, or
 * buildings/{buildingId}.adminFcmToken for the admin). These functions
 * watch for the events that should notify someone and do the sending.
 *
 * Every trigger is scoped by a {buildingId} wildcard, never a fixed id.
 * They were originally written against buildings/main when the app served
 * one society; once it supported many, that meant no society except the
 * original one ever received a single notification — silently, with
 * nothing logged, because no trigger was watching their paths at all.
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

async function adminToken(buildingId: string): Promise<string | undefined> {
  const buildingDoc = await db.doc(`buildings/${buildingId}`).get();
  return buildingDoc.data()?.adminFcmToken as string | undefined;
}

async function flatToken(
  buildingId: string,
  flatNumber: string
): Promise<string | undefined> {
  const flatDoc = await db
    .doc(`buildings/${buildingId}/flats/${flatNumber}`)
    .get();
  return flatDoc.data()?.fcmToken as string | undefined;
}

/** Fans a push out to every resident of one society. */
async function notifyAllResidents(
  buildingId: string,
  title: string,
  body: string,
  type: string
): Promise<void> {
  const flatsSnap = await db
    .collection(`buildings/${buildingId}/flats`)
    .get();
  await Promise.all(
    flatsSnap.docs.map((doc) =>
      sendPush(doc.data().fcmToken as string | undefined, title, body, type)
    )
  );
}

/** Paise → "₹8,000", matching how the app writes amounts everywhere. */
function formatPaise(paise: unknown): string {
  const n = typeof paise === "number" ? paise : 0;
  return `₹${(n / 100).toLocaleString("en-IN")}`;
}

// 1. New community notice → every resident with a registered token.
export const onNoticePosted = onDocumentCreated(
  "buildings/{buildingId}/posts/{postId}",
  async (event) => {
    const post = event.data?.data();
    if (!post) return;
    const title =
      typeof post.title === "string" && post.title.length > 0
        ? post.title
        : "New notice";
    await notifyAllResidents(
      event.params.buildingId,
      title,
      "Admin posted a new notice. Tap to view.",
      "new_notice"
    );
  }
);

// 2. Admin confirms a payment → that flat's resident.
export const onBillConfirmed = onDocumentUpdated(
  "buildings/{buildingId}/months/{monthId}/bills/{flatNumber}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.status === "confirmed" || after.status !== "confirmed") return;

    const token = await flatToken(
      event.params.buildingId,
      event.params.flatNumber
    );
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
  "buildings/{buildingId}/issues/{issueId}",
  async (event) => {
    const issue = event.data?.data();
    if (!issue) return;
    const token = await adminToken(event.params.buildingId);
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
  "buildings/{buildingId}/months/{monthId}/bills/{flatNumber}",
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

    const token = await adminToken(event.params.buildingId);
    await sendPush(
      token,
      "Payment screenshot uploaded",
      `Flat ${event.params.flatNumber} uploaded a payment screenshot, awaiting confirmation.`,
      "screenshot_uploaded"
    );
  }
);

// 5. Admin records a common-pool expense → every resident.
//
// Residents are paying for these, so they hear about them as they happen
// rather than discovering them in a bill at the end of the month.
export const onExpenseAdded = onDocumentCreated(
  "buildings/{buildingId}/months/{monthId}/expenses/{expenseId}",
  async (event) => {
    const expense = event.data?.data();
    if (!expense) return;
    const name =
      typeof expense.name === "string" && expense.name.length > 0
        ? expense.name
        : "New expense";
    await notifyAllResidents(
      event.params.buildingId,
      "New expense added",
      `${name} — ${formatPaise(expense.amountPaise)}`,
      "expense_added"
    );
  }
);

// 6. Admin edits an existing expense → every resident, with the reason.
//
// A quiet edit is the thing residents have most reason to distrust: an
// amount can change after they've seen it, and without this nothing would
// tell them it ever did. The reason the admin typed is carried into the
// notification itself, so the explanation arrives with the change rather
// than having to be gone looking for.
export const onExpenseChanged = onDocumentUpdated(
  "buildings/{buildingId}/months/{monthId}/expenses/{expenseId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const amountChanged = before.amountPaise !== after.amountPaise;
    const nameChanged = before.name !== after.name;
    if (!amountChanged && !nameChanged) return;

    const reason =
      typeof after.lastChangeReason === "string" &&
      after.lastChangeReason.length > 0
        ? after.lastChangeReason
        : "";

    const what = amountChanged
      ? `${formatPaise(before.amountPaise)} → ${formatPaise(after.amountPaise)}`
      : `renamed to "${after.name}"`;

    await notifyAllResidents(
      event.params.buildingId,
      `Expense changed: ${after.name}`,
      reason ? `${what} — ${reason}` : what,
      "expense_changed"
    );
  }
);
