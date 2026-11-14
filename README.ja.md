# Docker Compose で学ぶ耐量子暗号（ポスト量子暗号）ラボ：OpenSSL 3.5 と OpenSSH 10 による ML-KEM、ML-DSA、ハイブリッド TLS、耐量子 SSH

[English](README.md) | [Français](README.fr.md) | [日本語](README.ja.md) | [Español](README.es.md) | [Deutsch](README.de.md)

[![check](https://github.com/mitsurutech/lab-pq-lab/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-pq-lab/actions/workflows/check.yml)

授業ですぐに使える**耐量子暗号のラボ**です。学校や大学が学生一人ひとりに専用のデータベース、コンテナ、ブラウザ上のターミナルを用意できる [MitsuruTech Learning Platform](https://mitsurutech.co.uk/ja/learning) が提供しています。学生は本物の道具を使います。**ML-KEM**（FIPS 203）と **ML-DSA**（FIPS 204）を初めて標準で備えた **OpenSSL 3.5** と、耐量子鍵交換 `mlkem768x25519-sha256` を既定で使う **OpenSSH 10** です。隣では**ハイブリッドグループ X25519MLKEM768 を提供する TLS 1.3 サーバー**と **SSH サーバー**が動いています。ML-KEM と ML-DSA の鍵を作り、小さな認証局を動かし、実際の接続でどの鍵交換が合意されたかを読み取ります。何もインストールする必要はありません。

`docker-compose` のファイル `compose.yaml` ひとつだけでできていて、自分のパソコンでもプラットフォームでも同じように動きます。プラットフォームでは、どのコピーもインターネットに出られません。

## 中身

| サービス | イメージ | メモリ | 役割 |
| --- | --- | --- | --- |
| `pq` | [`buildpack-deps:trixie-scm`](https://hub.docker.com/_/buildpack-deps)（ダイジェストで固定） | 128 MB | 学生の作業用マシン。Debian 13、OpenSSL 3.5.7、OpenSSH 10.0p2 クライアント、Python 3 とフォルダー `/lab` |
| `tls` | 同じイメージ | 128 MB | ポート 4433 の `openssl s_server`。起動時に作る ML-DSA-65 の認証局が署名した証明書を使い、`X25519MLKEM768`、`X25519`、`MLKEM768` を提供 |
| `sshd` | [`linuxserver/openssh-server:10.3_p1-r2-ls243`](https://hub.docker.com/r/linuxserver/openssh-server) | 64 MB | ポート 2222 は既定設定の OpenSSH 10.3、ポート 2200 は `curve25519-sha256` と `ecdh-sha2-nistp256` だけを提供する古いサーバーの設定 |

**このリポジトリには鍵がひとつも入っていません。** 鍵、証明書、SSH のホスト鍵はすべて起動時に作られるので、二つのコピーが秘密を共有することはありません。作業用マシンの SSH 鍵と TLS のルート証明書は名前付きボリューム `keys` に保存されます。SSH サーバーはその鍵だけを受け入れ、イメージ自身の起動スクリプトを使わずに、権限のないアカウント `abc` で動きます。`/lab` に作ったファイルはラボを止めると消えます。

## プラットフォームで使う

種類 **Lab** のタスクを作り、**GitHub リポジトリから**を選んで、`https://github.com/mitsurutech/lab-pq-lab` とブランチ `main` を指定します。compose ファイルは既定の `compose.yaml` です。変更したい場合は先にフォークしてください。公開すると、学生のコピーはすべて公開したコミットから始まります。試すには[コンテナのページ](https://mitsurutech.co.uk/ja/container)を開き、**サンプルラボ**で**耐量子暗号**を探して開始を押します。Git と SQL 以外のラボには無料アカウントが必要です。

ヘルプマニュアルには[このラボのページ](https://mitsurutech.co.uk/ja/help/lab-pq-lab)があります。このラボは [Learning Platform](https://mitsurutech.co.uk/ja/learning) のモジュール「Post-quantum cryptography in practice」で使います。「今収集して後で解読」から移行計画までの 6 つのレッスンと、隠しテストで採点される Python の課題があります。

学校のアカウントがまだありませんか。学生 50 人までなら[最初の 1 年は無料](https://mitsurutech.co.uk/ja/pricing)で、[登録](https://mitsurutech.co.uk/ja/signup)にはメールアドレスだけが必要です。

## 自分のパソコンで動かす

Compose プラグイン付きの Docker が必要です。ラボはポートを開かないので、中に入って作業します。

```bash
docker compose up -d --wait
docker compose exec pq openssl version
```

止めるときは `docker compose down`、ボリュームも消すときは `docker compose down -v` です。自分のパソコンでは、下の `docker exec pq` を `docker compose exec pq` に読み替えてください。

## やってみる

ラボのターミナルから、`docker exec pq` で作業用マシンに入ります。各行の上のコメントが、表示される内容です。

```bash
# OpenSSL 3.5.7
docker exec pq openssl version
# ML-KEM-768 の鍵ペア。送り手は公開鍵でカプセル化し、持ち主がカプセルを開く
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

行末の `grep` は大事な 1 行だけを残します。`s_client` はサーバーのアドレスも、`ssh -v` はホスト鍵のフィンガープリントも表示しますが、これらはコピーごとに違います。

## 先生方へ

このラボには自動採点はありません。学生自身のコピーについて**短いレポートを提出させてください**。自分で選んだ 3 つのグループ一覧で合意された TLS グループ、自分の鍵で測った ML-KEM-512 と ML-KEM-1024 の公開鍵と暗号文の大きさ、`openssl verify` が受け入れる 3 段の ML-DSA 証明書チェーン（ルート、中間認証局、サーバー）、`sntrup761x25519-sha512` を強制したときの SSH 鍵交換です。最後に、今日録音された通信のうち、将来の量子コンピュータに破られうるのはどれかを 1 文で書かせます。コピーは学生本人のものですが、モジュールを教える教員は開くことができ、そのことは学生が読めるアクセスログに記録されます。

## ラボではできないこと

アルゴリズムと道具は本物ですが、環境は本番ではありません。鍵はファイルにあり、ハードウェアセキュリティモジュールやスマートカードはなく、インターネットにも出ません。WireGuard VPN に耐量子の鍵を加える **WireGuard と Rosenpass** は含まれていません。WireGuard にはカーネルモジュールとネットワークインターフェースを変える権限が必要で、ラボのコンテナにはそれがないためです。

## ラボの確認

`test/check.sh` はプラットフォームと同じ条件でラボを起動します（root のサービスに戻される権限以外はすべて外し、`no-new-privileges`、プロセス数とメモリの上限、インターネットなし）。そのうえで TLS のグループ、両方のポートでの SSH 鍵交換、SSH サーバーが権限のないアカウントで動くこと、上の大きさどおりの ML-KEM と ML-DSA、止めて再起動しても SSH 鍵が残ることを確かめます。Docker が必要で、プッシュのたびに実行されます。

```bash
test/check.sh
```

## バージョンとライセンス

OpenSSL は Apache-2.0、OpenSSH は BSD ライセンスです。作業用マシンのイメージは Debian の `buildpack-deps:trixie-scm`（Dockerfile は MIT）でダイジェストにより固定しています。SSH サーバーのイメージは [LinuxServer.io の openssh-server](https://github.com/linuxserver/docker-openssh-server)（パッケージングは GPL-3.0）、`10.3_p1-r2-ls243` です。どちらも改変せず、固定したバージョンで使います（`latest` は使いません）。

## ライセンス

この作品は [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.ja) で公開しています。Mitsuru Technologies Ltd の名前を示し、営利目的に使わず、作ったものを同じライセンスで共有するなら、学習と授業のために共有・改変できます。全文は `LICENSE` ファイルにあります。

## このラボについて

[Mitsuru Technologies](https://mitsurutech.co.uk) が [MitsuruTech Learning Platform](https://mitsurutech.co.uk/ja/learning) のために作りました。学校や大学向けに、ブラウザで Python、Java、Go、Node、SQL、Linux が使え、コンテナのラボ、GitHub からデプロイする Web アプリ、自動採点のクイズがあります。アカウントなしでコードを試すなら [playground](https://mitsurutech.co.uk/playground) へ。

ほかのラボ：[lab-cloud](https://github.com/mitsurutech/lab-cloud)、[lab-valkey](https://github.com/mitsurutech/lab-valkey)、[lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin)、[lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea)、[lab-sample](https://github.com/mitsurutech/lab-sample)。
