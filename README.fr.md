# Laboratoire de cryptographie post-quantique avec Docker Compose : ML-KEM, ML-DSA, TLS hybride et SSH post-quantique avec OpenSSL 3.5 et OpenSSH 10

[English](README.md) | [Français](README.fr.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Deutsch](README.de.md)

[![check](https://github.com/mitsurutech/lab-pq-lab/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-pq-lab/actions/workflows/check.yml)

Un **laboratoire de cryptographie post-quantique** prêt à l'emploi pour la classe, proposé par la [MitsuruTech Learning Platform](https://mitsurutech.co.uk/fr/learning), où les établissements donnent à chaque étudiant ses propres bases de données, conteneurs et terminal dans le navigateur. Chaque étudiant dispose des vrais outils : **OpenSSL 3.5**, première version à intégrer **ML-KEM** (FIPS 203) et **ML-DSA** (FIPS 204), et **OpenSSH 10**, qui négocie par défaut l'échange de clés post-quantique `mlkem768x25519-sha256`. À côté tournent un **serveur TLS 1.3 qui propose le groupe hybride X25519MLKEM768** et un **serveur SSH** : on crée des clés ML-KEM et ML-DSA, on fait tourner une petite autorité de certification et on lit l'échange de clés réellement négocié, sans rien installer.

Tout tient dans un seul fichier `docker-compose`, `compose.yaml`, qui fonctionne de la même façon sur votre machine et sur la plateforme, où aucune copie n'a accès à Internet.

## Ce qu'il contient

| Service | Image | Mémoire | Rôle |
| --- | --- | --- | --- |
| `pq` | [`buildpack-deps:trixie-scm`](https://hub.docker.com/_/buildpack-deps), épinglée par empreinte | 128 Mo | Le poste de l'étudiant : Debian 13 avec OpenSSL 3.5.7, le client OpenSSH 10.0p2, Python 3 et un dossier `/lab` |
| `tls` | la même image | 128 Mo | `openssl s_server` sur le port 4433, avec un certificat signé par une autorité ML-DSA-65 créée au démarrage, qui propose `X25519MLKEM768`, `X25519` et `MLKEM768` |
| `sshd` | [`linuxserver/openssh-server:10.3_p1-r2-ls243`](https://hub.docker.com/r/linuxserver/openssh-server) | 64 Mo | OpenSSH 10.3 sur le port 2222 avec les réglages par défaut, et sur le port 2200 configuré comme un ancien serveur qui ne propose que `curve25519-sha256` et `ecdh-sha2-nistp256` |

**Aucune clé n'est dans ce dépôt.** Les clés, les certificats et la clé d'hôte SSH sont créés au démarrage : deux copies ne partagent jamais de secret. La clé SSH du poste et le certificat racine TLS sont conservés dans le volume nommé `keys` ; le serveur SSH n'accepte que cette clé et tourne sous le compte non privilégié `abc` de son image, sans les scripts de démarrage de celle-ci. Les fichiers créés dans `/lab` disparaissent à l'arrêt du laboratoire.

## Sur la plateforme

Créez une tâche de type **Lab**, choisissez **Dans un dépôt GitHub** et indiquez `https://github.com/mitsurutech/lab-pq-lab` avec la branche `main` ; le fichier compose par défaut est `compose.yaml`. Faites d'abord une copie (fork) pour le modifier. Publiez : la copie de chaque étudiant part du commit publié. Pour l'essayer, ouvrez la [page des conteneurs](https://mitsurutech.co.uk/fr/container), trouvez **Post-quantique** dans **Laboratoires d'exemple** et cliquez sur Démarrer. Un compte gratuit est nécessaire pour tous les laboratoires sauf ceux de Git et de SQL.

Le manuel d'aide a une [page pour ce laboratoire](https://mitsurutech.co.uk/fr/help/lab-pq-lab). Le laboratoire accompagne le module « Post-quantum cryptography in practice » de la [Learning Platform](https://mitsurutech.co.uk/fr/learning) : six leçons, de « récolter maintenant, déchiffrer plus tard » jusqu'au plan de migration, avec des devoirs Python corrigés par des tests cachés.

Pas encore de compte établissement ? [La première année est gratuite](https://mitsurutech.co.uk/fr/pricing) jusqu'à 50 étudiants, et [l'inscription](https://mitsurutech.co.uk/fr/signup) ne demande qu'une adresse e-mail.

## Sur votre machine

Il vous faut Docker avec le plugin Compose. Le laboratoire n'ouvre aucun port, on travaille donc à l'intérieur :

```bash
docker compose up -d --wait
docker compose exec pq openssl version
```

Arrêtez-le avec `docker compose down`, et supprimez aussi son volume avec `docker compose down -v`. Sur votre machine, remplacez `docker exec pq` par `docker compose exec pq` dans les lignes ci-dessous.

## Prise en main

Dans le terminal du laboratoire, qui atteint le poste avec `docker exec pq`. Le commentaire au-dessus de chaque ligne dit ce qu'elle affiche.

```bash
# OpenSSL 3.5.7
docker exec pq openssl version
# Une paire de clés ML-KEM-768 ; l'expéditeur encapsule avec la clé publique, la propriétaire décapsule
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

Le `grep` en fin de ligne garde la seule ligne utile : `s_client` affiche aussi l'adresse du serveur et `ssh -v` l'empreinte de la clé d'hôte, qui changent d'une copie à l'autre.

## Pour les enseignants

Rien n'est corrigé automatiquement. **Demandez un court rapport** sur la copie de l'étudiant : le groupe TLS négocié pour trois listes de groupes de son choix, la taille de la clé publique et du chiffré pour ML-KEM-512 et ML-KEM-1024 avec ses propres clés, une chaîne de trois certificats ML-DSA (une racine, une autorité intermédiaire et un serveur) acceptée par `openssl verify`, et l'échange de clés SSH obtenu en imposant `sntrup761x25519-sha512`. Puis une phrase : lesquelles de ces connexions un enregistrement fait aujourd'hui permettrait-il de casser avec un futur ordinateur quantique ? Une copie est privée ; un membre de l'équipe qui enseigne le module peut l'ouvrir, et c'est inscrit dans le journal d'accès que l'étudiant peut lire.

## Ce qui ne fonctionne pas dans un laboratoire

Les algorithmes et les outils sont réels, mais le cadre n'est pas celui de la production : les clés sont dans des fichiers, il n'y a ni module matériel de sécurité ni carte à puce, et rien n'est exposé à Internet. **WireGuard avec Rosenpass**, qui ajoute une clé post-quantique à un VPN WireGuard, n'est pas inclus : WireGuard demande un module du noyau et des droits sur les interfaces réseau qu'un conteneur de laboratoire n'a pas.

## Vérifier le laboratoire

`test/check.sh` démarre le laboratoire comme le fait la plateforme (toutes les capacités retirées sauf celles rendues à un service root, `no-new-privileges`, une limite de processus et de mémoire, aucun accès à Internet), puis vérifie les groupes TLS, l'échange de clés SSH sur les deux ports, le compte non privilégié du serveur SSH, ML-KEM et ML-DSA avec les tailles ci-dessus, et que la clé SSH survit à un arrêt et un redémarrage. Il faut Docker ; il tourne à chaque push.

```bash
test/check.sh
```

## Versions et licences

OpenSSL est sous licence Apache-2.0 et OpenSSH sous licence BSD. L'image du poste est `buildpack-deps:trixie-scm` de Debian (Dockerfile sous MIT), épinglée par empreinte ; celle du serveur SSH est [openssh-server de LinuxServer.io](https://github.com/linuxserver/docker-openssh-server) (empaquetage GPL-3.0), `10.3_p1-r2-ls243`. Les deux sont utilisées sans modification et épinglées (jamais `latest`).

## Licence

Cette œuvre est sous licence [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.fr). Vous pouvez la partager et l'adapter pour apprendre et enseigner, en citant Mitsuru Technologies Ltd, sans usage commercial, et en partageant vos adaptations sous la même licence. Le texte complet est dans le fichier `LICENSE`.

## À propos

Réalisé par [Mitsuru Technologies](https://mitsurutech.co.uk) pour la [MitsuruTech Learning Platform](https://mitsurutech.co.uk/fr/learning) : Python, Java, Go, Node, SQL et Linux dans le navigateur pour les établissements, avec des laboratoires en conteneurs, des applications web déployées depuis GitHub et des quiz qui se corrigent seuls. Essayez du code sans compte dans le [bac à sable](https://mitsurutech.co.uk/playground).

D'autres laboratoires : [lab-cloud](https://github.com/mitsurutech/lab-cloud), [lab-valkey](https://github.com/mitsurutech/lab-valkey), [lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin), [lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea) et [lab-sample](https://github.com/mitsurutech/lab-sample).
