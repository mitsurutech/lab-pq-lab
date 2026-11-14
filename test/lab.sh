#!/usr/bin/env bash
# What the README promises, checked inside the lab's own services: run by check.sh.
#   lab.sh first   the README's steps
#   lab.sh after   the same servers answer the same way after a stop and a start
set -eu
# No pipefail here: grep -q stops reading early, and the command before it would count as failed.
: "${PROJECT:?run through test/check.sh}" "${OVERRIDE:?}"
phase=${1:?first or after}
root=$(cd "$(dirname "$0")/.." && pwd)
pq() { docker compose -p "$PROJECT" -f "$root/compose.yaml" -f "$OVERRIDE" exec -T pq "$@" < /dev/null; }
sshd() { docker compose -p "$PROJECT" -f "$root/compose.yaml" -f "$OVERRIDE" exec -T sshd "$@" < /dev/null; }
fail() { echo "FAIL: $*" >&2; exit 1; }
connect="openssl s_client -connect tls:4433 -servername tls -CAfile /keys/tls-ca.crt -brief"

echo "- the TLS server agrees the hybrid group by default and X25519 when asked"
out=$(pq sh -c "$connect 2>&1")
echo "$out" | grep -qx 'Negotiated TLS1.3 group: X25519MLKEM768' || fail "default group: $out"
echo "$out" | grep -qx 'Verification: OK' || fail "verification: $out"
echo "$out" | grep -qx 'Signature type: mldsa65' || fail "signature type: $out"
pq sh -c "$connect -groups X25519 2>&1" | grep -qx 'Peer Temp Key: X25519, 253 bits' || fail "X25519 only"
pq sh -c "$connect -groups MLKEM768 2>&1" | grep -qx 'Negotiated TLS1.3 group: MLKEM768' || fail "MLKEM768 only"

echo "- SSH agrees ML-KEM on 2222 and classical on the legacy server on 2200"
[ "$(pq ssh sshd whoami)" = abc ] || fail "login"
pq sh -c "ssh -v sshd true 2>&1" | grep -q 'kex: algorithm: mlkem768x25519-sha256' || fail "default kex"
pq sh -c "ssh -v legacy true 2>&1" | grep -q 'kex: algorithm: curve25519-sha256' || fail "legacy kex"
pq sh -c "ssh -v -o KexAlgorithms=sntrup761x25519-sha512 sshd true 2>&1" | grep -q 'kex: algorithm: sntrup761x25519-sha512' || fail "sntrup kex"
[ "$(sshd id -u)" = 911 ] || fail "sshd is not the unprivileged account"
[ "$phase" = after ] && exit 0

echo "- versions"
pq openssl version | grep -q '^OpenSSL 3\.5\.' || fail "openssl version"
pq sh -c "ssh -V 2>&1" | grep -q '^OpenSSH_10\.' || fail "ssh version"

echo "- ML-KEM-768 wraps and unwraps a 32-byte secret"
pq openssl genpkey -algorithm ML-KEM-768 -out kem.pem
pq openssl pkey -in kem.pem -pubout -out kem.pub
pq openssl pkeyutl -encap -inkey kem.pub -pubin -out ct.bin -secret sent.bin
pq openssl pkeyutl -decap -inkey kem.pem -in ct.bin -secret got.bin
pq diff -qs sent.bin got.bin | grep -qx 'Files sent.bin and got.bin are identical' || fail "secrets differ"
[ "$(pq sh -c 'wc -c < ct.bin' | tr -d ' ')" = 1088 ] || fail "ciphertext size"

echo "- ML-DSA-65 signs, and a changed message fails"
pq openssl genpkey -algorithm ML-DSA-65 -out signer.pem
pq openssl pkey -in signer.pem -pubout -out signer.pub
pq openssl pkeyutl -sign -rawin -inkey signer.pem -in notice.txt -out notice.sig
pq openssl pkeyutl -verify -rawin -pubin -inkey signer.pub -in notice.txt -sigfile notice.sig | grep -qx 'Signature Verified Successfully' || fail verify
[ "$(pq sh -c 'wc -c < notice.sig' | tr -d ' ')" = 3309 ] || fail "signature size"
pq sh -c "sed s/480/980/ notice.txt > changed.txt"
pq sh -c "openssl pkeyutl -verify -rawin -pubin -inkey signer.pub -in changed.txt -sigfile notice.sig > /dev/null 2>&1" && fail "a changed message verified"
echo "  all as the README says"
