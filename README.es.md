# Laboratorio de criptografía poscuántica con Docker Compose: ML-KEM, ML-DSA, TLS híbrido y SSH poscuántico con OpenSSL 3.5 y OpenSSH 10

[English](README.md) | [Français](README.fr.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Deutsch](README.de.md)

[![check](https://github.com/mitsurutech/lab-pq-lab/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-pq-lab/actions/workflows/check.yml)

Un **laboratorio de criptografía poscuántica** listo para usar en clase, de la [MitsuruTech Learning Platform](https://mitsurutech.co.uk/es/learning), donde los centros dan a cada estudiante sus propias bases de datos, contenedores y terminal en el navegador. Cada estudiante tiene las herramientas reales: **OpenSSL 3.5**, la primera versión que trae **ML-KEM** (FIPS 203) y **ML-DSA** (FIPS 204), y **OpenSSH 10**, que acuerda por defecto el intercambio de claves poscuántico `mlkem768x25519-sha256`. Al lado funcionan un **servidor TLS 1.3 que ofrece el grupo híbrido X25519MLKEM768** y un **servidor SSH**: creas claves ML-KEM y ML-DSA, montas una pequeña autoridad de certificación y lees qué intercambio de claves acordó de verdad una conexión, sin instalar nada.

Es un único archivo `docker-compose`, `compose.yaml`, y funciona igual en tu ordenador que en la plataforma, donde ninguna copia tiene salida a Internet.

## Qué contiene

| Servicio | Imagen | Memoria | Qué es |
| --- | --- | --- | --- |
| `pq` | [`buildpack-deps:trixie-scm`](https://hub.docker.com/_/buildpack-deps), fijada por digest | 128 MB | Tu puesto de trabajo: Debian 13 con OpenSSL 3.5.7, el cliente OpenSSH 10.0p2, Python 3 y una carpeta `/lab` |
| `tls` | la misma imagen | 128 MB | `openssl s_server` en el puerto 4433, con un certificado firmado por una autoridad ML-DSA-65 creada al arrancar, que ofrece `X25519MLKEM768`, `X25519` y `MLKEM768` |
| `sshd` | [`linuxserver/openssh-server:10.3_p1-r2-ls243`](https://hub.docker.com/r/linuxserver/openssh-server) | 64 MB | OpenSSH 10.3 en el puerto 2222 con los valores por defecto, y en el 2200 configurado como un servidor antiguo que solo ofrece `curve25519-sha256` y `ecdh-sha2-nistp256` |

**No hay ninguna clave en este repositorio.** Las claves, los certificados y la clave de host SSH se crean al arrancar, así que dos copias nunca comparten un secreto. La clave SSH del puesto y el certificado raíz TLS se guardan en el volumen con nombre `keys`; el servidor SSH solo deja entrar esa clave y se ejecuta con la cuenta sin privilegios `abc` de su imagen, sin los scripts de arranque de esta. Los archivos creados en `/lab` se pierden al parar el laboratorio.

## En la plataforma

Crea una tarea de tipo **Lab**, elige **En un repositorio de GitHub** e indica `https://github.com/mitsurutech/lab-pq-lab` con la rama `main`; el archivo compose por defecto es `compose.yaml`. Haz antes un fork si quieres cambiarlo. Publica, y la copia de cada estudiante parte del commit publicado. Para probarlo, abre la [página de contenedores](https://mitsurutech.co.uk/es/container), busca **Poscuántica** en **Laboratorios de ejemplo** y pulsa Iniciar. Hace falta una cuenta gratuita para todos los laboratorios menos los de Git y SQL.

El manual de ayuda tiene una [página para este laboratorio](https://mitsurutech.co.uk/es/help/lab-pq-lab). El laboratorio acompaña al módulo «Post-quantum cryptography in practice» de la [Learning Platform](https://mitsurutech.co.uk/es/learning): seis lecciones, de «cosechar ahora, descifrar después» al plan de migración, con tareas en Python corregidas por pruebas ocultas.

¿Aún sin cuenta de centro? [El primer año es gratis](https://mitsurutech.co.uk/es/pricing) hasta 50 estudiantes, y [registrarse](https://mitsurutech.co.uk/es/signup) solo pide un correo.

## En tu ordenador

Necesitas Docker con el plugin Compose. El laboratorio no abre ningún puerto, así que se trabaja dentro:

```bash
docker compose up -d --wait
docker compose exec pq openssl version
```

Páralo con `docker compose down`, y borra también su volumen con `docker compose down -v`. En tu ordenador usa `docker compose exec pq` donde las líneas de abajo dicen `docker exec pq`.

## Paso a paso

En el terminal del laboratorio, que llega al puesto con `docker exec pq`. El comentario de cada línea dice lo que imprime.

```bash
# OpenSSL 3.5.7
docker exec pq openssl version
# Un par de claves ML-KEM-768; quien envía encapsula con la clave pública y la dueña desencapsula
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

El `grep` final deja solo la línea que importa: `s_client` imprime también la dirección del servidor y `ssh -v` la huella de la clave de host, que cambian en cada copia.

## Para docentes

Nada se corrige automáticamente. **Pide un informe breve** sobre la copia del estudiante: el grupo TLS acordado para tres listas de grupos que haya elegido, el tamaño de la clave pública y del texto cifrado de ML-KEM-512 y ML-KEM-1024 con sus propias claves, una cadena de tres certificados ML-DSA (una raíz, una autoridad intermedia y un servidor) que `openssl verify` acepte, y el intercambio de claves SSH acordado al forzar `sntrup761x25519-sha512`. Después, una frase: ¿cuáles de esas conexiones podría romper un futuro ordenador cuántico a partir de una grabación hecha hoy? Cada copia es privada; un docente del módulo puede abrirla, y queda en el registro de acceso que el estudiante puede leer.

## Lo que no funciona en un laboratorio

Los algoritmos y las herramientas son reales, pero el entorno no es de producción: las claves están en archivos, no hay módulo de seguridad hardware ni tarjeta inteligente y nada da a Internet. **WireGuard con Rosenpass**, que añade una clave poscuántica a una VPN WireGuard, no está incluido: WireGuard necesita un módulo del núcleo y permisos sobre las interfaces de red que un contenedor de laboratorio no tiene.

## Comprobar el laboratorio

`test/check.sh` arranca el laboratorio como lo hace la plataforma (todas las capacidades quitadas salvo las que se devuelven a un servicio root, `no-new-privileges`, límites de procesos y de memoria, sin salida a Internet) y comprueba los grupos TLS, el intercambio de claves SSH en los dos puertos, la cuenta sin privilegios del servidor SSH, ML-KEM y ML-DSA con los tamaños de arriba, y que la clave SSH sobrevive a parar y arrancar de nuevo. Necesita Docker y se ejecuta en cada push.

```bash
test/check.sh
```

## Versiones y licencias

OpenSSL tiene licencia Apache-2.0 y OpenSSH licencia BSD. La imagen del puesto es `buildpack-deps:trixie-scm` de Debian (Dockerfile con licencia MIT), fijada por digest; la del servidor SSH es [openssh-server de LinuxServer.io](https://github.com/linuxserver/docker-openssh-server) (empaquetado GPL-3.0), `10.3_p1-r2-ls243`. Las dos se usan sin modificar y fijadas (nunca `latest`).

## Licencia

Esta obra está bajo licencia [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.es). Puedes compartirla y adaptarla para aprender y enseñar, si citas a Mitsuru Technologies Ltd, no la usas con fines comerciales y compartes lo que hagas con la misma licencia. El texto completo está en el archivo `LICENSE`.

## Acerca de

Hecho por [Mitsuru Technologies](https://mitsurutech.co.uk) para la [MitsuruTech Learning Platform](https://mitsurutech.co.uk/es/learning): Python, Java, Go, Node, SQL y Linux en el navegador para centros educativos, con laboratorios en contenedores, aplicaciones web desplegadas desde GitHub y cuestionarios que se corrigen solos. Prueba código sin cuenta en el [playground](https://mitsurutech.co.uk/playground).

Más laboratorios: [lab-cloud](https://github.com/mitsurutech/lab-cloud), [lab-valkey](https://github.com/mitsurutech/lab-valkey), [lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin), [lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea) y [lab-sample](https://github.com/mitsurutech/lab-sample).
