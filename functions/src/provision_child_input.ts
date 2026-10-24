import {randomBytes} from "node:crypto";

export interface ProvisionChildInput {
  childId: string;
  email: string;
}

export class InvalidProvisionChildInputError extends Error {}

const allowedKeys = new Set(["childId", "email"]);
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function parseProvisionChildInput(data: unknown): ProvisionChildInput {
  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    throw new InvalidProvisionChildInputError("Invalid request data.");
  }

  const record = data as Record<string, unknown>;
  if (Object.keys(record).some((key) => !allowedKeys.has(key))) {
    throw new InvalidProvisionChildInputError("Unexpected request fields.");
  }

  if (typeof record.childId !== "string" || typeof record.email !== "string") {
    throw new InvalidProvisionChildInputError("Missing required fields.");
  }

  const childId = record.childId.trim();
  const email = record.email.trim().toLowerCase();
  if (childId.length === 0 || childId.includes("/")) {
    throw new InvalidProvisionChildInputError("Invalid child identifier.");
  }
  if (!emailPattern.test(email)) {
    throw new InvalidProvisionChildInputError("Invalid email.");
  }

  return {childId, email};
}

export function generateTemporaryPassword(): string {
  return `${randomBytes(32).toString("base64url")}aA1!`;
}
