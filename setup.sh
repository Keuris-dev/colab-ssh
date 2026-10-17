#!/usr/bin/env bash
# colab-ssh bridge — SSH ke VM Colab (sshd + portwarp host-tetap + pinggy fallback)
# tempel di cell Colab:  %%bash  lalu isi cell ini, Run.
# gak pakai set -e: tiap langkah dicek manual biar gak mati di tengah.

echo "== colab-ssh bridge =="

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO=sudo

# ---------- 1. sshd ----------
export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update -qq >/dev/null 2>&1 || true
$SUDO apt-get install -y -qq openssh-server >/dev/null 2>&1 || echo "apt: openssh-server gagal (cek Runtime → Internet On)"

PASS="col$(head -c 32 /dev/urandom | sha256sum | cut -c 1-16)"
echo "root:$PASS" | $SUDO chpasswd

$SUDO mkdir -p /etc/ssh/sshd_config.d /run/sshd
printf 'PermitRootLogin yes\nPasswordAuthentication yes\nKbdInteractiveAuthentication yes\n' \
  | $SUDO tee /etc/ssh/sshd_config.d/99-colab-ssh.conf >/dev/null
if $SUDO grep -q '^PermitRootLogin' /etc/ssh/sshd_config 2>/dev/null; then
  $SUDO sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
else
  echo 'PermitRootLogin yes' | $SUDO tee -a /etc/ssh/sshd_config >/dev/null
fi
if $SUDO grep -q '^PasswordAuthentication' /etc/ssh/sshd_config 2>/dev/null; then
  $SUDO sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
else
  echo 'PasswordAuthentication yes' | $SUDO tee -a /etc/ssh/sshd_config >/dev/null
fi

$SUDO pkill -f '/usr/sbin/[s]shd' 2>/dev/null || true
sleep 1
if $SUDO /usr/sbin/sshd -t 2>/dev/null; then
  $SUDO /usr/sbin/sshd
  echo "sshd: nyala (proses: $(pgrep -c -f '/usr/sbin/[s]shd' 2>/dev/null || echo '?'))"
else
  echo "sshd: config invalid — cek: $SUDO /usr/sbin/sshd -t"
fi

# ---------- 2. portwarp (opsional, host tetap) ----------
PWRP=""
PW_CRED_B64="${PW_CRED_B64:-}"
if [ -n "$PW_CRED_B64" ]; then
  mkdir -p "$HOME/.portwarp"
  printf '%s' "$PW_CRED_B64" | base64 -d > "$HOME/.portwarp/credentials.json" 2>/dev/null \
    && chmod 600 "$HOME/.portwarp/credentials.json"
  T="pwrp-0.3.7-linux-amd64.tar.gz"
  if curl -fsSL --retry 3 -o "/tmp/$T" "https://portwarp.com/download/$T" \
    && curl -fsSL --retry 3 -o /tmp/pwrp.sum https://portwarp.com/download/checksums.txt; then
    echo "portwarp: download $(stat -c%s /tmp/$T) bytes"
    if (cd /tmp && grep "$T" pwrp.sum | sha256sum -c - >/dev/null 2>&1); then
      if tar -xzf "/tmp/$T" -C /tmp pwrp && $SUDO mv /tmp/pwrp /usr/local/bin/pwrp && $SUDO chmod +x /usr/local/bin/pwrp; then
        echo "portwarp: CLI ok"
        pwrp connect --all --detach > /tmp/pwrp.log 2>&1 || true
        for i in $(seq 1 90); do
          PWRP=$(grep -oE '[a-z0-9]+\.free\.pwrp\.cc:[0-9]+' /tmp/pwrp.log 2>/dev/null | head -1 || true)
          [ -n "$PWRP" ] && break
          sleep 1
        done
        echo "portwarp: ${PWRP:-gagal — tail /tmp/pwrp.log}"
      else
        echo "portwarp: extract gagal"
      fi
    else
      echo "portwarp: checksum FAIL"
    fi
  else
    echo "portwarp: download gagal"
  fi
  [ -z "$PWRP" ] && echo "portwarp: catatan — free cuma1 tunnel; kalo Frepees/Kaggle lagi nyala, tabrakan"
else
  echo "portwarp: skip (opsional — isi PW_CRED_B64, lihat README)"
fi

# ---------- 3. pinggy (fallback instan, URL ganti tiap ±60 menit) ----------
: > /tmp/pinggy.log
nohup bash -c '
  while true; do
    ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR -o ConnectTimeout=10 -o ServerAliveInterval=15 \
        -o ExitOnForwardFailure=yes -T -p 443 -R0:localhost:22 tcp@free.pinggy.io 2>&1 | \
    while IFS= read -r line; do echo "$line"; done
    echo ">> pinggy putus, reconnect dalam 3 detik..."
    sleep 3
  done
' </dev/null >> /tmp/pinggy.log 2>&1 &
PJURL=""
for i in $(seq 1 45); do
  PJURL=$(grep -oE 'tcp://[A-Za-z0-9.-]+:[0-9]+' /tmp/pinggy.log 2>/dev/null | head -1 || true)
  [ -n "$PJURL" ] && break
  sleep 1
done
echo "pinggy: ${PJURL:-cek /tmp/pinggy.log}"

# ---------- 4. ringkasan ----------
PJB64=$(printf '%s' "$PJURL" | sed -E 's|^tcp://||')
PJHOST=$(printf '%s' "$PJB64" | sed -E 's|:[0-9]+$||')
PJPORT=$(printf '%s' "$PJB64" | sed -E 's|^.*:([0-9]+)$|\1|')
{
  echo "USER root"
  echo "PASS $PASS"
  echo "PINGGY_HOST $PJHOST"
  echo "PINGGY_PORT $PJPORT"
  echo "PORTWARP $PWRP"
} | $SUDO tee /tmp/kgpu_conn.txt >/dev/null

echo "=============================="
cat /tmp/kgpu_conn.txt
echo "=============================="
nvidia-smi 2>/dev/null | head -15 || echo "GPU: gak ada — Runtime → Change runtime type → GPU"
echo "WAJIB: tab Colab jangan ditutup + jalankan cell keep-alive (sesi free mati kalo idle/tab ditutup)"
