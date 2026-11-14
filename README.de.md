# Labor für Post-Quanten-Kryptografie mit Docker Compose: ML-KEM, ML-DSA, hybrides TLS und Post-Quanten-SSH mit OpenSSL 3.5 und OpenSSH 10

[English](README.md) | [Français](README.fr.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Deutsch](README.de.md)

[![check](https://github.com/mitsurutech/lab-pq-lab/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-pq-lab/actions/workflows/check.yml)

Ein fertiges **Labor für Post-Quanten-Kryptografie** für den Unterricht, von der [MitsuruTech Learning Platform](https://mitsurutech.co.uk/de/learning), auf der Schulen und Hochschulen allen Lernenden eigene Datenbanken, Container und ein Terminal im Browser geben. Jede und jeder bekommt die echten Werkzeuge: **OpenSSL 3.5**, die erste Version mit **ML-KEM** (FIPS 203) und **ML-DSA** (FIPS 204), und **OpenSSH 10**, das standardmäßig den Post-Quanten-Schlüsselaustausch `mlkem768x25519-sha256` aushandelt. Daneben laufen ein **TLS-1.3-Server mit der hybriden Gruppe X25519MLKEM768** und ein **SSH-Server**: Sie erzeugen ML-KEM- und ML-DSA-Schlüssel, betreiben eine kleine Zertifizierungsstelle und lesen ab, welcher Schlüsselaustausch tatsächlich ausgehandelt wurde, ohne etwas zu installieren.

Alles steckt in einer einzigen `docker-compose`-Datei, `compose.yaml`. Sie läuft auf Ihrem Rechner genauso wie auf der Plattform, wo keine Kopie ins Internet kommt.

## Was drin ist

| Dienst | Image | Speicher | Was es ist |
| --- | --- | --- | --- |
| `pq` | [`buildpack-deps:trixie-scm`](https://hub.docker.com/_/buildpack-deps), per Digest festgelegt | 128 MB | Der Arbeitsplatz: Debian 13 mit OpenSSL 3.5.7, dem OpenSSH-10.0p2-Client, Python 3 und einem Ordner `/lab` |
| `tls` | dasselbe Image | 128 MB | `openssl s_server` auf Port 4433 mit einem Zertifikat, das eine beim Start erzeugte ML-DSA-65-Zertifizierungsstelle signiert hat; angeboten werden `X25519MLKEM768`, `X25519` und `MLKEM768` |
| `sshd` | [`linuxserver/openssh-server:10.3_p1-r2-ls243`](https://hub.docker.com/r/linuxserver/openssh-server) | 64 MB | OpenSSH 10.3 auf Port 2222 mit den Standardeinstellungen und auf Port 2200 wie ein alter Server, der nur `curve25519-sha256` und `ecdh-sha2-nistp256` anbietet |

**In diesem Repository liegt kein Schlüssel.** Alle Schlüssel, Zertifikate und der SSH-Hostschlüssel entstehen beim Start, zwei Kopien teilen also nie ein Geheimnis. Der SSH-Schlüssel des Arbeitsplatzes und das TLS-Wurzelzertifikat liegen im benannten Volume `keys`; der SSH-Server lässt nur diesen Schlüssel herein und läuft unter dem unprivilegierten Konto `abc` seines Images, ohne dessen eigene Startskripte. Dateien in `/lab` gehen beim Stoppen des Labors verloren.

## Auf der Plattform

Legen Sie eine Aufgabe vom Typ **Lab** an, wählen Sie **In einem GitHub-Repository** und geben Sie `https://github.com/mitsurutech/lab-pq-lab` mit dem Branch `main` an; die Compose-Datei ist standardmäßig `compose.yaml`. Forken Sie es zuerst, wenn Sie etwas ändern möchten. Nach dem Veröffentlichen startet jede Kopie vom veröffentlichten Commit. Zum Ausprobieren öffnen Sie die [Container-Seite](https://mitsurutech.co.uk/de/container), suchen **Post-Quanten** unter **Beispiellabore** und klicken auf Starten. Für alle Labore außer Git und SQL ist ein kostenloses Konto nötig.

Das Hilfehandbuch hat eine [Seite zu diesem Labor](https://mitsurutech.co.uk/de/help/lab-pq-lab). Das Labor gehört zum Modul „Post-quantum cryptography in practice“ der [Learning Platform](https://mitsurutech.co.uk/de/learning): sechs Lektionen, von „jetzt speichern, später entschlüsseln“ bis zum Migrationsplan, mit Python-Aufgaben, die versteckte Tests bewerten.

Noch kein Konto für Ihre Einrichtung? [Das erste Jahr ist kostenlos](https://mitsurutech.co.uk/de/pricing) für bis zu 50 Lernende, und die [Anmeldung](https://mitsurutech.co.uk/de/signup) braucht nur eine E-Mail-Adresse.

## Auf dem eigenen Rechner

Sie brauchen Docker mit dem Compose-Plugin. Das Labor öffnet keinen Port, gearbeitet wird also darin:

```bash
docker compose up -d --wait
docker compose exec pq openssl version
```

Stoppen mit `docker compose down`, samt Volume entfernen mit `docker compose down -v`. Auf dem eigenen Rechner steht `docker compose exec pq`, wo unten `docker exec pq` steht.

## Schritt für Schritt

Im Terminal des Labors, das den Arbeitsplatz mit `docker exec pq` erreicht. Der Kommentar über jeder Zeile sagt, was sie ausgibt.

```bash
# OpenSSL 3.5.7
docker exec pq openssl version
# Ein ML-KEM-768-Schlüsselpaar; der Absender kapselt mit dem öffentlichen Schlüssel, die Besitzerin entkapselt
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

Das `grep` am Ende behält nur die wichtige Zeile: `s_client` gibt auch die Adresse des Servers aus und `ssh -v` den Fingerabdruck des Hostschlüssels, die sich in jeder Kopie unterscheiden.

## Für Lehrende

Nichts wird automatisch bewertet. **Verlangen Sie einen kurzen Bericht** über die eigene Kopie: die ausgehandelte TLS-Gruppe für drei selbst gewählte Gruppenlisten, die Größe von öffentlichem Schlüssel und Chiffrat für ML-KEM-512 und ML-KEM-1024 mit eigenen Schlüsseln, eine Kette aus drei ML-DSA-Zertifikaten (Wurzel, Zwischenzertifizierungsstelle und Server), die `openssl verify` akzeptiert, und den SSH-Schlüsselaustausch beim Erzwingen von `sntrup761x25519-sha512`. Dazu ein Satz: Welche dieser Verbindungen könnte ein künftiger Quantencomputer aus einer heute gemachten Aufzeichnung brechen? Jede Kopie ist privat; Lehrende des Moduls können sie öffnen, und das steht im Zugriffsprotokoll, das die Lernenden lesen können.

## Was in einem Labor nicht geht

Algorithmen und Werkzeuge sind echt, die Umgebung ist aber keine Produktion: Schlüssel liegen in Dateien, es gibt kein Hardware-Sicherheitsmodul und keine Chipkarte, und nichts ist aus dem Internet erreichbar. **WireGuard mit Rosenpass**, das einem WireGuard-VPN einen Post-Quanten-Schlüssel hinzufügt, fehlt: WireGuard braucht ein Kernelmodul und Rechte an Netzwerkschnittstellen, die ein Labor-Container nicht hat.

## Das Labor prüfen

`test/check.sh` startet das Labor so wie die Plattform (alle Capabilities entzogen bis auf die, die ein Root-Dienst zurückbekommt, `no-new-privileges`, Prozess- und Speichergrenzen, kein Internet) und prüft die TLS-Gruppen, den SSH-Schlüsselaustausch auf beiden Ports, das unprivilegierte Konto des SSH-Servers, ML-KEM und ML-DSA mit den Größen oben und dass der SSH-Schlüssel ein Stoppen und Neustarten übersteht. Es braucht Docker und läuft bei jedem Push.

```bash
test/check.sh
```

## Versionen und Lizenzen

OpenSSL steht unter Apache-2.0, OpenSSH unter einer BSD-Lizenz. Das Image des Arbeitsplatzes ist Debians `buildpack-deps:trixie-scm` (Dockerfile unter MIT), per Digest festgelegt; das des SSH-Servers ist [openssh-server von LinuxServer.io](https://github.com/linuxserver/docker-openssh-server) (Paketierung unter GPL-3.0), `10.3_p1-r2-ls243`. Beide laufen unverändert und festgelegt (nie `latest`).

## Lizenz

Dieses Werk steht unter [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.de). Sie dürfen es zum Lernen und Lehren teilen und bearbeiten, wenn Sie Mitsuru Technologies Ltd nennen, es nicht kommerziell nutzen und Bearbeitungen unter derselben Lizenz weitergeben. Der vollständige Text steht in der Datei `LICENSE`.

## Über uns

Von [Mitsuru Technologies](https://mitsurutech.co.uk) für die [MitsuruTech Learning Platform](https://mitsurutech.co.uk/de/learning): Python, Java, Go, Node, SQL und Linux im Browser für Schulen und Hochschulen, mit Container-Laboren, Web-Apps aus GitHub und Quizzen, die sich selbst bewerten. Code ohne Konto ausprobieren im [Playground](https://mitsurutech.co.uk/playground).

Weitere Labore: [lab-cloud](https://github.com/mitsurutech/lab-cloud), [lab-valkey](https://github.com/mitsurutech/lab-valkey), [lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin), [lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea) und [lab-sample](https://github.com/mitsurutech/lab-sample).
