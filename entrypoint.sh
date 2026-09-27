#!/bin/bash
echo "================================================"
echo " WildRig-Multi · Pearlhash Startup Check"
echo "================================================"

# Cek versi driver NVIDIA
DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 | cut -d'.' -f1)

if [ -z "$DRIVER_VERSION" ]; then
    echo "⚠️  WARNING: NVIDIA driver tidak terdeteksi!"
    echo "   GPU mining tidak akan berjalan."
elif [ "$DRIVER_VERSION" -lt 580 ]; then
    echo "❌ NVIDIA Driver v${DRIVER_VERSION} — TERLALU LAMA!"
    echo "   Pearlhash (Blackwell) butuh driver v580+"
    echo "   GPU mining akan gagal. Update driver di host!"
else
    echo "✅ NVIDIA Driver v${DRIVER_VERSION} — OK"
    echo "   GPU pearlhash siap jalan."
fi

# Validasi ENV wajib
MISSING=0
if [ -z "$PRL_WALLET" ]; then
    echo "❌ PRL_WALLET belum diisi!"
    MISSING=1
fi
if [ -z "$PRL_POOL" ]; then
    echo "❌ PRL_POOL belum diisi!"
    MISSING=1
fi
if [ "$MISSING" -eq 1 ]; then
    echo ""
    echo "Isi semua ENV yang wajib lalu restart container."
    exit 1
fi

echo ""
echo "  PRL_POOL   : $PRL_POOL"
echo "  PRL_WALLET : $PRL_WALLET"
echo "  PRL_WORKER : $PRL_WORKER"
echo "================================================"
echo ""

ARGS=(--algo pearlhash --url "$PRL_POOL" --user "$PRL_WALLET")

if [ -n "$PRL_WORKER" ]; then
    ARGS+=(--worker "$PRL_WORKER")
fi

if [ -n "$PRL_PASS" ]; then
    ARGS+=(--pass "$PRL_PASS")
fi

/usr/local/bin/wildrig-multi "${ARGS[@]}" 2>&1

EXIT_CODE=$?
echo ""
echo "❌ WildRig-Multi berhenti dengan exit code: $EXIT_CODE"
exit $EXIT_CODE
