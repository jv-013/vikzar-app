import { randomInt } from "node:crypto";

// Excludes visually-ambiguous characters (0/O, 1/I/L) — this code gets
// read aloud and typed by hand in a locker room, not copy-pasted.
const ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 8;

/** A cryptographically random, unguessable, human-typeable invite code. */
export function generateInviteCode(): string {
  let code = "";
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += ALPHABET[randomInt(ALPHABET.length)];
  }
  return code;
}
