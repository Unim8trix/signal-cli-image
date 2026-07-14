# signal-cli-image

A minimal, trustworthy container image that runs [`signal-cli`](https://github.com/AsamK/signal-cli)
as an HTTP/JSON-RPC daemon — built to be used as a **sidecar** so another app
(e.g. [Hermes Agent](https://github.com/NousResearch/hermes-agent)) can send and
receive Signal messages over `http://127.0.0.1:8080`.

**Image:** `ghcr.io/unim8trix/signal-cli`

## Why this exists

- There is **no official `signal-cli` image**, and the popular `bbernhard/signal-cli-rest-api`
  ships a JRE and exposes a *different* REST protocol. This image uses the
  **native `signal-cli` build** (GraalVM, **no Java runtime**) and speaks the
  daemon's native `--http` JSON-RPC interface that apps like Hermes expect.
- **Trust by construction:** the binary is downloaded from the official AsamK
  release and **GPG-verified** at build time (see below). We build it ourselves
  rather than trusting a third-party image that holds our linked Signal account.

## Features

- `debian:13-slim` + native `signal-cli` (single binary, no JRE) + `qrencode`
- GPG-verified download of the pinned release
- Runs as **non-root** (UID/GID `10000`)
- **Crash-loop-free start:** the entrypoint *waits* until the device is linked,
  then starts the daemon automatically — no restart needed
- In-terminal **QR linking** helper

## Configuration

| Env var             | Default              | Purpose                                              |
|---------------------|----------------------|------------------------------------------------------|
| `SIGNAL_ACCOUNT`    | *(required)*         | phone number in E.164 format, e.g. `+49151…`     |
| `SIGNAL_CONFIG`     | `/var/lib/signal-cli`| signal-cli config/account dir — **persist this**     |
| `SIGNAL_HTTP_BIND`  | `127.0.0.1:8080`     | Daemon HTTP bind. Loopback is right for a sidecar.   |

Persist `SIGNAL_CONFIG` on a volume — it holds the linked account (keys, session).

## Usage

### 1. Link the device (one-time, interactive)

Your phone stays the **primary** device; this links `signal-cli` as a **secondary** device.

```sh
# local test with Docker:
docker run --rm -it \
  -e SIGNAL_ACCOUNT="+49151XXXXXXX" \
  -v signal-cli-data:/var/lib/signal-cli \
  --entrypoint link.sh \
  ghcr.io/unim8trix/signal-cli
```

A QR code is printed in the terminal. Scan it in the Signal app under
**Settings › Linked Devices › Link New Device**. Once linked, the account is
written to the volume.

### 2. Run the daemon

```sh
docker run -d --name signal-cli \
  -e SIGNAL_ACCOUNT="+49151XXXXXXX" \
  -v signal-cli-data:/var/lib/signal-cli \
  ghcr.io/unim8trix/signal-cli
```

The default entrypoint waits until the account is linked, then serves the
JSON-RPC daemon on `SIGNAL_HTTP_BIND`. Point your app at it, e.g.
`SIGNAL_HTTP_URL=http://127.0.0.1:8080`.

### As a Kubernetes sidecar

```yaml
containers:
  - name: app
    env:
      - { name: SIGNAL_HTTP_URL, value: "http://127.0.0.1:8080" }
  - name: signal-cli
    image: ghcr.io/unim8trix/signal-cli@sha256:<digest>   # pin by digest
    env:
      - { name: SIGNAL_ACCOUNT, valueFrom: { secretKeyRef: { name: app-secrets, key: SIGNAL_ACCOUNT } } }
    volumeMounts:
      - { name: data, mountPath: /var/lib/signal-cli, subPath: signal-cli }
```

Link the device once it's running:

```sh
kubectl exec -it deploy/<app> -c signal-cli -- link.sh
```

## Image tags & pinning

Tags: `latest`, the version (e.g. `0.14.6`), and `sha-<commit>`. For deployments,
**pin by digest** (`…@sha256:…`) and let [Renovate](https://docs.renovatebot.com/)
propose updates.

## Security

- **GPG verification:** the build imports AsamK's release-signing key
  (`FA10826A74907F9EC6BBB7FC2BA2CD21B5B09570`) and verifies the `.asc` signature.
  **Verify this fingerprint independently** (e.g. the Arch AUR `signal-cli`
  `validpgpkeys`, or keys.openpgp.org) before trusting it.
- Runs as non-root (UID 10000); no extra capabilities required.
- The linked account (in `SIGNAL_CONFIG`) is **sensitive** — treat that volume
  like a secret and back it up accordingly.
- Keep `signal-cli` **current**: old versions can stop working as Signal's server
  APIs change. Bump `SIGNAL_CLI_VERSION` (in `Dockerfile` and the workflow tag).

## Building

Pushes to `main` (and a weekly schedule) trigger the GitHub Actions workflow,
which builds `linux/amd64` and pushes to `ghcr.io/unim8trix/signal-cli`.

Build locally:

```sh
docker build --build-arg SIGNAL_CLI_VERSION=0.14.6 -t signal-cli:local .
```

## Credits & license

`signal-cli` is developed by [AsamK](https://github.com/AsamK/signal-cli) (GPLv3).
This repository only packages it; the scripts here are provided as-is.
Signal is a trademark of the Signal Foundation — this project is **unofficial**
and not affiliated with or endorsed by Signal.
