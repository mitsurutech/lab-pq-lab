# Post-quantum cryptography lab with Docker Compose: ML-KEM, ML-DSA, hybrid TLS and post-quantum SSH with OpenSSL 3.5 and OpenSSH 10

[English](README.md) | [Français](README.fr.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Deutsch](README.de.md)

[![check](https://github.com/mitsurutech/lab-pq-lab/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-pq-lab/actions/workflows/check.yml)

A ready-made **post-quantum cryptography lab** for classrooms, from the [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning), where schools and colleges give every student their own databases, containers and terminal in the browser. Each student gets the real post-quantum tools: **OpenSSL 3.5**, the first version to ship **ML-KEM** (FIPS 203) and **ML-DSA** (FIPS 204), and **OpenSSH 10**, which agrees the post-quantum key exchange `mlkem768x25519-sha256` by default. Beside them run a **TLS 1.3 server offering the hybrid group X25519MLKEM768** and an **SSH server**, so students make ML-KEM and ML-DSA keys, run a small certificate authority, and read which key exchange a real connection agreed, with nothing to install.

It is one `docker-compose` file, `compose.yaml`, and it runs the same on your own machine as it does on the platform, where every copy has no way out to the internet.

## What is in it

| Service | Image | Memory | What it is |
| --- | --- | --- | --- |
| `pq` | [`buildpack-deps:trixie-scm`](https://hub.docker.com/_/buildpack-deps), pinned by digest | 128 MB | The student's workstation: Debian 13 with OpenSSL 3.5.7, the OpenSSH 10.0p2 client and Python 3, and a folder `/lab` |
| `tls` | the same image | 128 MB | `openssl s_server` on port 4433, with a certificate signed by an ML-DSA-65 certificate authority it makes at start, offering `X25519MLKEM768`, `X25519` and `MLKEM768` |
| `sshd` | [`linuxserver/openssh-server:10.3_p1-r2-ls243`](https://hub.docker.com/r/linuxserver/openssh-server) | 64 MB | OpenSSH 10.3 on port 2222 with the defaults, and on port 2200 set up like an old server offering only `curve25519-sha256` and `ecdh-sha2-nistp256` |

**No key is in this repository.** Every key, certificate and SSH host key is made when the lab starts, so no two copies share a secret. The workstation's SSH key and the TLS root certificate are kept in the named volume `keys`; the SSH server lets in that key alone, and runs as its image's unprivileged account `abc` without the image's own start-up scripts. Files made in `/lab` are lost when the lab stops. Each service peaked under 20 MB while the commands below were run.

## Using it on the platform

Make a task of type **Lab**, choose **In a GitHub repository** and give `https://github.com/mitsurutech/lab-pq-lab` with the branch `main`; the compose file is the default, `compose.yaml`. Fork it first to change it. Publish, and every student's copy starts from the commit you published. To try it first, open the [container page](https://mitsurutech.co.uk/container), find **Post-quantum cryptography** in **Sample labs** and press Start. A free account is needed for every lab except the Git and SQL ones.

The help manual has a [page for this lab](https://mitsurutech.co.uk/help/lab-pq-lab) and a [guide to container labs](https://mitsurutech.co.uk/help/labs). The lab goes with the module [Post-quantum cryptography in practice](https://mitsurutech.co.uk/resources/university/post-quantum-crypto) of the [Learning Platform](https://mitsurutech.co.uk/learning): six lessons, from harvest now, decrypt later to planning a migration, with Python assignments marked by hidden tests.

No college account yet? [Your first year is free](https://mitsurutech.co.uk/pricing) for up to 50 students, and [signing up](https://mitsurutech.co.uk/signup) takes an email address.

## Running it on your own machine

You need Docker with the Compose plugin. The lab opens no port, so you work inside it:

```bash
docker compose up -d --wait
docker compose exec pq openssl version
```

Stop it with `docker compose down`, and remove its volume too with `docker compose down -v`. On your own machine use `docker compose exec pq` where the lines below say `docker exec pq`.

## Working through it

In the lab's terminal, which reaches the workstation with `docker exec pq`. Each step prints what the comment says it will.

```bash
# OpenSSL 3.5.7
docker exec pq openssl version
# An ML-KEM-768 key pair; the sender encapsulates with the public key, the owner decapsulates
docker exec pq openssl genpkey -algorithm ML-KEM-768 -out ana.pem
docker exec pq openssl pkey -in ana.pem -pubout -out ana.pub
docker exec pq openssl pkeyutl -encap -inkey ana.pub -pubin -out wrapped.bin -secret sender.bin
docker exec pq openssl pkeyutl -decap -inkey ana.pem -in wrapped.bin -secret ana.bin
# Files sender.bin and ana.bin are identical
docker exec pq diff -qs sender.bin ana.bin
# 1088 wrapped.bin, 32 sender.bin, 32 ana.bin
docker exec pq wc -c wrapped.bin sender.bin ana.bin
# Negotiated TLS1.3 group: X25519MLKEM768
docker exec pq sh -c "openssl s_client -connect tls:4433 -servername tls -CAfile /keys/tls-ca.crt -brief 2>&1 | grep group"
# Peer Temp Key: X25519, 253 bits
docker exec pq sh -c "openssl s_client -connect tls:4433 -servername tls -CAfile /keys/tls-ca.crt -brief -groups X25519 2>&1 | grep Temp"
# debug1: kex: algorithm: mlkem768x25519-sha256
docker exec pq sh -c "ssh -v sshd true 2>&1 | grep 'kex: algorithm'"
# debug1: kex: algorithm: curve25519-sha256
docker exec pq sh -c "ssh -v legacy true 2>&1 | grep 'kex: algorithm'"
```

The `grep` at the end of the TLS and SSH lines keeps the one line that matters: `s_client` also prints the server's address, and `ssh -v` the host key's fingerprint, which differ in every copy.

## For teachers

Nothing in this lab is marked automatically. **Ask for a short report** on the student's own copy: the TLS group agreed for three client group lists they chose, the public key and ciphertext sizes of ML-KEM-512 and ML-KEM-1024 from their own keys, a chain of three ML-DSA certificates (a root, an intermediate CA and a server) that `openssl verify` accepts, and the SSH key exchange agreed when they force `sntrup761x25519-sha512`. Then one sentence on which of those connections a recording made today could be broken by a future quantum computer. A copy is private to the student who started it, and a member of staff who teaches the module can open it, which is written to the access log the student can read.

## What does not work in a lab

The algorithms and tools are real, but the setting is not production: keys live in files, there is no hardware security module or smart card, and nothing faces the internet. **WireGuard with Rosenpass**, which adds a post-quantum key to a WireGuard VPN, is not here, because WireGuard needs a kernel module and rights to change network interfaces that a lab container does not have. The lab has no way out to the internet, so nothing can be downloaded into it.

## Checking the lab

`test/check.sh` starts the lab the way the platform's runner starts every service (all capabilities dropped except those a root service is given back, `no-new-privileges`, a process limit, a memory limit and no way out to the internet) and then checks that the TLS server agrees the groups this page says, that SSH agrees ML-KEM on 2222 and classical on 2200, that the SSH server runs as an unprivileged account, that ML-KEM and ML-DSA work with the sizes above, and that the SSH key survives the containers being removed and started again. It needs Docker and runs on every push.

```bash
test/check.sh
```

## Versions and licences

OpenSSL is Apache-2.0 and OpenSSH is BSD-licensed. The workstation image is Debian's `buildpack-deps:trixie-scm` (its Dockerfile MIT), pinned by digest; the SSH server image is [LinuxServer.io's openssh-server](https://github.com/linuxserver/docker-openssh-server) (GPL-3.0 packaging), `10.3_p1-r2-ls243`. Both are run unmodified and pinned (never `latest`).

## Licence

This work is licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/). You may share it and adapt it for learning and teaching, if you credit Mitsuru Technologies Ltd, do not use it commercially, and share anything you make from it under the same licence. The full text is in the `LICENSE` file.

## About

Made by [Mitsuru Technologies](https://mitsurutech.co.uk) for the [MitsuruTech Learning Platform](https://mitsurutech.co.uk/learning): Python, Java, Go, Node, SQL and Linux in the browser for schools and colleges, with container labs, web apps deployed from GitHub, and quizzes that mark themselves. Try code with no account in the [playground](https://mitsurutech.co.uk/playground).

More labs from the same place: [lab-cloud](https://github.com/mitsurutech/lab-cloud), [lab-valkey](https://github.com/mitsurutech/lab-valkey), [lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin), [lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea) and [lab-sample](https://github.com/mitsurutech/lab-sample).
