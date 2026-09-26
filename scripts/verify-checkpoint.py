#!/usr/bin/env python3
"""verify-checkpoint.py ANCHOR CHECKPOINT [PUBLIC_KEY...]

Verifies that CHECKPOINT (a signed note, WIST-3 section 5) carries a signature
under the Anchor's genesis key or under one of the extra base64url-encoded raw
Ed25519 public keys given, and that its origin line equals the Anchor's log_id.
Exit 0 when verified, 1 otherwise. Requires python3-cryptography.
"""
import base64
import hashlib
import json
import sys

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

AGGREGATOR_KEY_TYPE = 0x01
SIGNATURE_PREFIX = "— "


def b64url_decode(text):
    return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


def note_key_id(name, public_key):
    digest = hashlib.sha256(name.encode() + bytes([0x0A, AGGREGATOR_KEY_TYPE]) + public_key).digest()
    return digest[:4]


def main(argv):
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    with open(argv[1], encoding="utf-8") as f:
        anchor = json.load(f)["anchor"]
    with open(argv[2], "rb") as f:
        note = f.read().decode("utf-8")
    keys = [b64url_decode(anchor["genesis_key"]["public_key"])] + [b64url_decode(k) for k in argv[3:]]

    text, _, signatures = note.partition("\n\n")
    text += "\n"
    lines = text.split("\n")
    if lines[0] != anchor["log_id"]:
        print(f"origin {lines[0]!r} is not the Anchor's log_id {anchor['log_id']!r}", file=sys.stderr)
        return 1
    expected = {note_key_id(anchor["log_id"], k): k for k in keys}
    for line in signatures.split("\n"):
        if not line.startswith(SIGNATURE_PREFIX + anchor["log_id"] + " "):
            continue
        blob = base64.b64decode(line.split(" ", 2)[2])
        key = expected.get(blob[:4])
        if key is None:
            continue
        try:
            Ed25519PublicKey.from_public_bytes(key).verify(blob[4:], text.encode("utf-8"))
        except InvalidSignature:
            print("a signature line naming a known key fails to verify", file=sys.stderr)
            return 1
        print(f"checkpoint verified: origin {lines[0]}, tree size {lines[1]}")
        return 0
    print("no signature line under a known key", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
