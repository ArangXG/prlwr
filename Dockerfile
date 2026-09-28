FROM nvidia/cuda:12.8.0-runtime-ubuntu22.04

ARG WILDRIG_VERSION
ARG CACHEBUST=1

RUN apt-get update && apt-get install -y \
    libstdc++6 \
    libgomp1 \
    ca-certificates \
    libnuma1 \
    libhwloc15 \
    ocl-icd-libopencl1 \
    curl \
    jq \
    xz-utils \
    tar \
    && rm -rf /var/lib/apt/lists/*

# ── Download WildRig Multi ──────────────────────────────────────
# Kalau WILDRIG_VERSION tidak di-passing (mis. build manual/lokal),
# otomatis ambil rilis "latest" dari GitHub.
RUN set -e; \
    echo "cachebust=$CACHEBUST"; \
    if [ -z "$WILDRIG_VERSION" ]; then \
        WILDRIG_VERSION=$(curl -s https://api.github.com/repos/andru-kun/wildrig-multi/releases/latest | jq -r '.tag_name'); \
    fi; \
    echo "Building dengan WildRig Multi versi: $WILDRIG_VERSION"; \
    ASSET_URL=$(curl -s "https://api.github.com/repos/andru-kun/wildrig-multi/releases/tags/${WILDRIG_VERSION}" \
        | jq -r '.assets[] | select(.name | test("linux"; "i")) | .browser_download_url' | head -n1); \
    if [ -z "$ASSET_URL" ]; then \
        echo "Gagal menemukan asset linux untuk versi $WILDRIG_VERSION" >&2; \
        exit 1; \
    fi; \
    echo "Download: $ASSET_URL"; \
    mkdir -p /tmp/wildrig && cd /tmp/wildrig && \
    curl -L -o wildrig.pkg "$ASSET_URL" && \
    tar -xf wildrig.pkg && \
    BIN=$(find /tmp/wildrig -maxdepth 3 -type f -iname "wildrig*" \
        | grep -viE '\.(txt|md|cfg|json|sh|bat|conf|ini|log)$' | head -n1) && \
    cp "$BIN" /usr/local/bin/wildrig-multi && \
    chmod +x /usr/local/bin/wildrig-multi && \
    cd / && rm -rf /tmp/wildrig

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ── GPU Mining · PearlHash · Pearl ───────────────────────────
ENV PRL_POOL=
ENV PRL_WALLET=
ENV PRL_WORKER=
ENV PRL_PASS=
ENV PRL_POOL2=
ENV PRL_MAX_REJECTS=5

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
