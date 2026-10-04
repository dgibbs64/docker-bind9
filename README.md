# BIND 9 Docker Image

<p align="center">
<a href="https://hub.docker.com/r/dgibbs/bind9"><img src="https://img.shields.io/docker/pulls/dgibbs/bind9.svg?style=flat-square&amp;logo=docker&amp;logoColor=white" alt="Docker Pulls"></a>
<a href="https://github.com/dgibbs64/docker-bind9/actions"><img alt="GitHub Workflow Status" src="https://img.shields.io/github/actions/workflow/status/dgibbs64/docker-bind9/action-docker-publish.yml?style=flat-square"></a>
<a href="https://github.com/dgibbs64/docker-bind9/blob/main/LICENSE.md"><img src="https://img.shields.io/github/license/dgibbs64/docker-bind9?style=flat-square" alt="MIT License"></a></p>

## About

[BIND 9](https://www.isc.org/bind/) DNS server on Debian 13 (trixie), for `amd64` and `arm64` (including Raspberry Pi).

BIND comes from [packages.sury.org](https://packages.sury.org/bind/), maintained by Ondřej Surý, the Debian BIND maintainer, so the image tracks the latest upstream 9.20 release rather than a distribution snapshot. A daily check rebuilds the image within a day of a new BIND release, and it is rebuilt weekly regardless to pick up Debian security updates.

The image is available on [Docker Hub](https://hub.docker.com/r/dgibbs/bind9) and [GitHub Container Registry](https://github.com/dgibbs64/docker-bind9/pkgs/container/bind9).

### Why another BIND image?

- The official `internetsystemsconsortium/bind9` image is `amd64` only.
- `ubuntu/bind9` follows the Ubuntu archive, so it can be several BIND releases behind upstream.

This image uses the standard Debian file layout, so it works as a drop-in replacement for `ubuntu/bind9`.

## Tags

| Tag(s)   | Contents                                 |
| -------- | ---------------------------------------- |
| `latest` | Latest BIND 9.20 release                 |
| `9.20`   | Latest BIND 9.20 release                 |
| `9.20.x` | A specific BIND release (e.g. `9.20.29`) |

## Usage

```bash
docker run -d --name bind9 \
  -p 53:53/udp -p 53:53/tcp \
  -v "$PWD/config:/etc/bind" \
  -v "$PWD/cache:/var/cache/bind" \
  -v "$PWD/records:/var/lib/bind" \
  dgibbs/bind9:latest
```

### Docker Compose

```yaml
services:
  bind9:
    image: dgibbs/bind9:latest
    container_name: bind9
    environment:
      - TZ=Europe/London
      - PUID=1000
      - PGID=1000
    volumes:
      - ./config:/etc/bind
      - ./cache:/var/cache/bind
      - ./records:/var/lib/bind
    network_mode: host
    restart: unless-stopped
```

## Volumes

| Path              | Purpose                                             |
| ----------------- | --------------------------------------------------- |
| `/etc/bind`       | Configuration (`named.conf`) and zone files         |
| `/var/cache/bind` | Working directory (`directory` option), cache, keys |
| `/var/lib/bind`   | Secondary and dynamically updated zones             |

If `/etc/bind` is mounted, it must contain a `named.conf`. If you mount an empty directory, copy the defaults out of the image first:

```bash
docker run --rm --entrypoint tar dgibbs/bind9:latest -C /etc/bind -c . | tar -C ./config -x
```

## User, UID & GID (PUID / PGID)

`named` drops privileges to the `bind` user. Set `PUID` and `PGID` to make it run as a host user, so files it writes to mounted volumes are owned by that user. On start, the entrypoint makes sure `/var/cache/bind`, `/var/lib/bind`, `/var/log/bind` and `/run/named` are owned by that user.

`BIND9_USER` is also honoured, for compatibility with `ubuntu/bind9`.

## named Options

Arguments starting with `-` are passed to `named`. The default is `-g` (foreground, log to stderr, so `docker logs` shows everything).

```bash
# IPv4 only (useful on Docker networks without IPv6)
docker run -d dgibbs/bind9:latest -g -4
```

Anything else runs as a command, e.g. `docker run --rm dgibbs/bind9 named-checkconf -z`.

## rndc

A unique `rndc.key` is generated in `/etc/bind` on first start if one does not exist. No key is baked into the image.

```bash
docker exec bind9 rndc status
docker exec bind9 rndc reload
```

## Health Check

The image's health check queries `127.0.0.1` and treats any answer, including `REFUSED`, as healthy. It checks that `named` is running and answering, not that recursion works, so it suits configurations that restrict queries with views or ACLs.

## Migrating from ubuntu/bind9

- Mount points are the same: `/etc/bind`, `/var/cache/bind`, `/var/lib/bind`.
- There is no Pebble. Drop any Pebble layer mounts and pass `named` flags as the container command instead (e.g. `-g -4`).
- Set `PUID`/`PGID` instead of granting ACLs to the Ubuntu image's `bind` uid (9970).
