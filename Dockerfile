FROM debian:13-slim

ARG SIGNAL_CLI_VERSION=0.14.6
# AsamK (Sebastian Scheibner) release-signing key — verify this fingerprint
# independently before trusting it (e.g. Arch AUR validpgpkeys, keys.openpgp.org).
ARG SIGNAL_CLI_GPG_FPR=FA10826A74907F9EC6BBB7FC2BA2CD21B5B09570

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg dirmngr qrencode; \
    rm -rf /var/lib/apt/lists/*

# Download the native signal-cli build, GPG-verify it, then install.
RUN set -eux; cd /tmp; \
    base="https://github.com/AsamK/signal-cli/releases/download/v${SIGNAL_CLI_VERSION}"; \
    curl -fsSL -o s.tar.gz     "${base}/signal-cli-${SIGNAL_CLI_VERSION}-Linux-native.tar.gz"; \
    curl -fsSL -o s.tar.gz.asc "${base}/signal-cli-${SIGNAL_CLI_VERSION}-Linux-native.tar.gz.asc"; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "${SIGNAL_CLI_GPG_FPR}"; \
    gpg --batch --verify s.tar.gz.asc s.tar.gz; \
    tar -xzf s.tar.gz -C /opt; \
    ln -sf /opt/signal-cli /usr/local/bin/signal-cli; \
    gpgconf --kill all; rm -rf "$GNUPGHOME" s.tar.gz s.tar.gz.asc; \
    signal-cli --version   # smoke test: fails the build if a runtime lib is missing

# Non-root runtime user (matches the pod fsGroup).
RUN useradd -u 10000 -m -d /home/signalcli signalcli; \
    mkdir -p /var/lib/signal-cli; \
    chown -R 10000:10000 /var/lib/signal-cli /home/signalcli

COPY --chmod=0755 entrypoint.sh link.sh /usr/local/bin/

ENV HOME=/home/signalcli TMPDIR=/tmp \
    SIGNAL_CONFIG=/var/lib/signal-cli SIGNAL_HTTP_BIND=127.0.0.1:8080
USER 10000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
