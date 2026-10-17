# colab-ssh

SSH ke **VM Google Colab** (root Ubuntu + GPU) — pola Frepees: pinggy instan, host tetap opsional via Portwarp.

| | isi |
|---|---|
| GPU | T4/L4/apa adanya — gak dijamin, cek `!nvidia-smi` tiap sesi (Runtime → Change runtime type → GPU) |
| Sesi | **maks 12 jam**, idle → disconnect (periodenya gak di-publish) |
| Tab | **wajib kebuka** — free tier gak ada background execution, tab ditutup = VM dibuang |
| Auth | user `root`, password acak `col...` (muncul tiap run) |

## Pakai (3 menit)

1. Buka [colab.research.google.com](https://colab.research.google.com) → notebook baru.
2. **Runtime → Change runtime type → T4 GPU**, pastikan internet On (default on).
3. Bikin cell `%%bash` → tempel isi `setup.sh` (atau upload `colab-ssh.ipynb`).
4. **Run** → baca output:
   ```
   USER root
   PASS col.............
   PINGGY_HOST ....pinggy-free.link
   PINGGY_PORT ....
   ```
5. **Terminus (HP)** → New Host → `root` / `PASS` / host+port pinggy.
6. **Run cell keep-alive** (biar idle-timeout gak nendang) — **jangan tutup tab Colab**.
7. URL pinggy ganti tiap ±60 menit → **cell refresh** buat URL baru, reconnect.

## Portwarp (host tetap, opsional)

Sebelum setup, isi dulu di cell (atau gabung):

```bash
export PW_CRED_B64=$(base64 -w0 ~/.portwarp/credentials.json)
```

⚠️ Portwarp free = **1 tunnel**. Frepees / Kaggle lagi nyala → tabrakan. Pilih salah satu online.

## Batasan (biar gak kaget)

- **Tab ditutup / idle / lewat12 jam** → VM hilang, `/content` bersih lagi. Yang penting simpen ke Drive atau repo.
- **ToS Colab**: tunneling SSH masuk daftar aktivitas yang di-restrict — pola pemakaian wajar (sesi normal, gak nambang 24/7) aman, tapi ini risiko yang nempel; kalau kena limit, ganti akun atau putar ke Kaggle.
- GPU quota = compute units harian, gak ada angka pasti — limit dinamis menurut demand.
- Keep-alive ngehindarin idle-timeout, tapi **gak ngelebihin batas12 jam** — sesi mati = run ulang setup (password & URL baru).

## Files

- `setup.sh` — isi cell `%%bash`
- `colab-ssh.ipynb` — notebook siap upload (setup + keep-alive + refresh)
