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
if [ -n "$PRL_POOL2" ]; then
    echo "  PRL_POOL2  : $PRL_POOL2 (backup)"
fi
echo "  PRL_WALLET : $PRL_WALLET"
echo "  PRL_WORKER : $PRL_WORKER"
echo "  MAX_REJECTS: ${PRL_MAX_REJECTS:-5}"
echo "================================================"
echo ""

# Opsi global dulu, baru grup pool (url/user/pass) supaya urutannya rapi
ARGS=(--algo pearlhash --max-rejects "${PRL_MAX_REJECTS:-5}")

if [ -n "$PRL_WORKER" ]; then
    ARGS+=(--worker "$PRL_WORKER")
fi

# Pool utama
ARGS+=(--url "$PRL_POOL" --user "$PRL_WALLET")
if [ -n "$PRL_PASS" ]; then
    ARGS+=(--pass "$PRL_PASS")
fi

# Pool cadangan (opsional) — dipakai saat pool utama gagal konek
# atau kena reject beruntun sebanyak --max-rejects
if [ -n "$PRL_POOL2" ]; then
    ARGS+=(--url "$PRL_POOL2" --user "$PRL_WALLET")
    if [ -n "$PRL_PASS" ]; then
        ARGS+=(--pass "$PRL_PASS")
    fi
fi

# ── Watchdog ────────────────────────────────────────────────────
# WildRig tidak exit sendiri saat "CUDA error" — prosesnya tetap hidup
# tapi hashrate 0. Loop ini mendeteksi error itu, mematikan miner, lalu
# menjalankannya lagi. Bisa diatur lewat ENV (opsional):
#   MAX_CUDA_ERRORS  jumlah baris "CUDA error" sebelum restart (default 3)
#   MAX_RESTARTS     restart beruntun sebelum menyerah        (default 5)
MAX_CUDA_ERRORS=${MAX_CUDA_ERRORS:-3}
MAX_RESTARTS=${MAX_RESTARTS:-5}
BIN=/usr/local/bin/wildrig-multi
LOG=/tmp/wildrig.log
RESTARTS=0

trap 'kill $MINER_PID $TAIL_PID 2>/dev/null; exit 0' TERM INT

while true; do
    : > "$LOG"
    tail -n +1 -F "$LOG" 2>/dev/null &
    TAIL_PID=$!

    START=$(date +%s)
    "$BIN" "${ARGS[@]}" >> "$LOG" 2>&1 &
    MINER_PID=$!

    while kill -0 "$MINER_PID" 2>/dev/null; do
        sleep 10
        if [ "$(grep -c 'CUDA error' "$LOG")" -ge "$MAX_CUDA_ERRORS" ]; then
            echo ""
            echo "❌ Terdeteksi CUDA error berulang — GPU berhenti hashing. Mematikan miner..."
            kill "$MINER_PID" 2>/dev/null
            sleep 3
            kill -9 "$MINER_PID" 2>/dev/null
            break
        fi
    done

    wait "$MINER_PID" 2>/dev/null
    EXIT_CODE=$?
    sleep 1
    kill "$TAIL_PID" 2>/dev/null

    echo ""
    echo "❌ WildRig-Multi berhenti (exit code: $EXIT_CODE)"

    # Kalau sempat jalan > 30 menit, anggap stabil dan reset hitungan restart
    if [ $(( $(date +%s) - START )) -gt 1800 ]; then
        RESTARTS=0
    fi

    RESTARTS=$((RESTARTS + 1))
    if [ "$RESTARTS" -gt "$MAX_RESTARTS" ]; then
        echo "❌ Sudah restart ${MAX_RESTARTS}x berturut-turut. Menyerah — cek GPU/host."
        exit 1
    fi

    echo "🔄 Restart miner (${RESTARTS}/${MAX_RESTARTS}) dalam 10 detik..."
    sleep 10
done
