# 🚀 S-Mart Server Migration Playbook & Guide
# คู่มือและขั้นตอนการย้ายระบบเซิร์ฟเวอร์สู่ Mini PC (Proxmox VE)

> **Document Version / เวอร์ชันเอกสาร:** 1.0.0 (August 2026)  
> **Target Hardware / ฮาร์ดแวร์เป้าหมาย:** Beelink Mini S12 Pro (Intel 12th Gen N100, 32GB RAM, 500GB NVMe SSD)  
> **Base Operating System / ระบบปฏิบัติการหลัก:** Proxmox VE 9.x (x86_64)  
> **Source of Truth / ข้อมูลหลัก:** Local MySQL Database on LXC + POS Desktop Shelf Backend API

---

## 📑 Table of Contents / สารบัญ
1. [System Architecture & Resource Allocation / สถาปัตยกรรมระบบและการจัดสรรทรัพยากร](#1-system-architecture--resource-allocation)
2. [Pre-Migration Checklist / สิ่งที่ต้องเตรียมก่อนเริ่มย้ายระบบ](#2-pre-migration-checklist)
3. [Phase 1: Proxmox Host Installation & Setup / ขั้นตอนติดตั้ง Proxmox บนเครื่องแม่](#3-phase-1-proxmox-host-installation--setup)
4. [Phase 2: LXC 100 - MySQL Database Setup / ขั้นตอนสร้างตู้ฐานข้อมูล](#4-phase-2-lxc-100---mysql-database-setup)
5. [Phase 3: LXC 101 - Backend API Setup / ขั้นตอนสร้างตู้ Backend API](#5-phase-3-lxc-101---backend-api-setup)
6. [Phase 4: LXC 102 - Cloudflare Tunnel / ขั้นตอนเชื่อมต่อ Cloudflare Tunnel](#6-phase-4-lxc-102---cloudflare-tunnel)
7. [Phase 5: UPS Auto-Shutdown Setup / ติดตั้งระบบป้องกันไฟดับอัตโนมัติ](#7-phase-5-ups-auto-shutdown-setup)
8. [Phase 6: Client Switching & Verification / การสลับเครื่องลูกและทดสอบระบบ](#8-phase-6-client-switching--verification)
9. [Disaster Recovery & Rollback Plan / แผนกู้คืนฉุกเฉินและย้อนกลับ](#9-disaster-recovery--rollback-plan)

---

## 1. System Architecture & Resource Allocation
### สถาปัตยกรรมระบบและการจัดสรรทรัพยากร

```
┌────────────────────────────────────────────────────────────────────────┐
│                   BEELINK MINI S12 PRO (32GB RAM / 500GB SSD)          │
│                      Proxmox VE 9.x Host (IP: 192.168.1.200)           │
├───────────────────┬───────────────────┬───────────────────┬────────────┤
│ 📦 LXC 100        │ 📦 LXC 101        │ 📦 LXC 102        │ 📦 LXC 103 │
│ MySQL Database    │ Backend API       │ Cloudflare Tunnel │ Test/Clone │
│ IP: 192.168.1.201 │ IP: 192.168.1.202 │ IP: 192.168.1.203 │ (Sandbox)  │
│ RAM: 8 GB         │ RAM: 4 GB         │ RAM: 1 GB         │ RAM: 4 GB  │
│ Disk: 40 GB       │ Disk: 20 GB       │ Disk: 10 GB       │ Disk: 20 GB│
└───────────────────┴───────────────────┴───────────────────┴────────────┘
```

---

## 2. Pre-Migration Checklist
### สิ่งที่ต้องเตรียมก่อนเริ่มย้ายระบบ

- [ ] **Flash Drive:** 1x USB Flash Drive (8GB+) flashed with **Proxmox VE 9.x ISO (x86_64)** via Rufus (DD mode) or Ventoy.
- [ ] **UPS Battery:** Replace old UPS battery with new 12V 7Ah–9Ah SLA battery and connect USB Data cable to Mini PC.
- [ ] **Current Database Backup / สำรองฐานข้อมูลเดิม:** Dump current MySQL from POS Desktop:
  ```bash
  mysqldump -u root -p smartpos > current_pos_backup.sql
  ```
- [ ] **Network IP Planning / แผนผังไอพี:**
  - Router Gateway: `192.168.1.1`
  - Proxmox Host: `192.168.1.200`
  - LXC 100 (MySQL): `192.168.1.201`
  - LXC 101 (Backend API): `192.168.1.202`
  - LXC 102 (Cloudflare): `192.168.1.203`

---

## 3. Phase 1: Proxmox Host Installation & Setup
### ขั้นตอนติดตั้ง Proxmox บนเครื่องแม่

1. **Install Proxmox VE:**
   - Plug USB -> Boot into BIOS (Press `F7` or `Del`) -> Enable `Intel Virtualization (VT-x)` -> Boot Proxmox Installer.
   - Target Harddisk: `nvme0n1` (500GB SSD)
   - Management IP: `192.168.1.200/24`, Gateway: `192.168.1.1`, DNS: `192.168.1.1` or `1.1.1.1`.
2. **Access Web GUI:** Open browser from Cashier PC: `https://192.168.1.200:8006` (Login as `root`).
3. **Run Post-Install Commands / รันคำสั่งปลดล็อกระบบ (In Proxmox Node Shell):**
   ```bash
   # Switch to free no-subscription repository
   sed -i -e 's|^deb https://enterprise.proxmox.com/debian/pve|#deb https://enterprise.proxmox.com/debian/pve|g' /etc/apt/sources.list.d/pve-enterprise.list
   echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" >> /etc/apt/sources.list

   # Update system
   apt update && apt dist-upgrade -y

   # Install vital utilities
   apt install -y curl wget git htop apcupsd nut-client
   ```
4. **Download Ubuntu 24.04 / 22.04 Container Template:**
   - Go to `local (pve)` -> `CT Templates` -> `Templates` -> Download `ubuntu-24.04-standard` or `ubuntu-22.04-standard`.

---

## 4. Phase 2: LXC 100 - MySQL Database Setup
### ขั้นตอนสร้างตู้ฐานข้อมูล

1. **Create LXC Container (ID: 100):**
   - Name: `mysql-db` | OS: `Ubuntu 24.04` | Disks: `40GB` | CPU: `2 Cores` | RAM: `8192 MB` | Swap: `2048 MB`
   - Network: Static IPv4 `192.168.1.201/24`, Gateway `192.168.1.1`
2. **Install & Start MySQL inside LXC 100 Console:**
   ```bash
   apt update && apt install -y mysql-server
   systemctl enable --now mysql
   ```
3. **Configure High-Performance MySQL (`/etc/mysql/conf.d/smartpos.cnf`):**
   ```ini
   [mysqld]
   bind-address = 0.0.0.0
   innodb_buffer_pool_size = 4G
   innodb_log_buffer_size = 256M
   innodb_flush_log_at_trx_commit = 2
   innodb_flush_method = O_DIRECT
   character-set-server = utf8mb4
   collation-server = utf8mb4_unicode_ci
   max_connections = 250
   ```
   Restart MySQL: `systemctl restart mysql`
4. **Create Database & User / สร้างฐานข้อมูลและกำหนดสิทธิ์:**
   ```sql
   CREATE DATABASE smartpos CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE USER 'smartpos_user'@'%' IDENTIFIED BY 'Set_Your_Secure_Password_Here';
   GRANT ALL PRIVILEGES ON smartpos.* TO 'smartpos_user'@'%';
   FLUSH PRIVILEGES;
   ```
5. **Restore Existing Data / นำเข้าข้อมูลบิลและสินค้าเดิม:**
   ```bash
   mysql -u smartpos_user -p smartpos < current_pos_backup.sql
   ```
6. **Setup Automated Nightly Backup / ตั้งระบบสำรองข้อมูลทุกคืน (`/opt/backup_db.sh`):**
   ```bash
   #!/bin/bash
   BACKUP_DIR="/var/backups/smartpos_mysql"
   DATE=$(date +'%Y-%m-%d_%H%M%S')
   mkdir -p $BACKUP_DIR
   mysqldump -u smartpos_user -p'Set_Your_Secure_Password_Here' smartpos | gzip > "$BACKUP_DIR/smartpos_$DATE.sql.gz"
   find $BACKUP_DIR -type f -name "*.sql.gz" -mtime +14 -delete
   ```
   Add to cron: `crontab -e` -> `0 0 * * * /opt/backup_db.sh`

---

## 5. Phase 3: LXC 101 - Backend API Setup
### ขั้นตอนสร้างตู้ Backend API

1. **Create LXC Container (ID: 101):**
   - Name: `backend-api` | OS: `Ubuntu 24.04` | Disks: `20GB` | CPU: `2 Cores` | RAM: `4096 MB`
   - Network: Static IPv4 `192.168.1.202/24`, Gateway `192.168.1.1`
2. **Install Dart SDK inside LXC 101:**
   ```bash
   apt update && apt install -y curl git unzip
   wget https://storage.googleapis.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-linux-x64-release.zip
   unzip dartsdk-linux-x64-release.zip -d /opt/
   echo 'export PATH="$PATH:/opt/dart-sdk/bin"' >> ~/.bashrc
   source ~/.bashrc
   ```
3. **Deploy Backend Source Code / นำโค้ด Backend มาวาง (`/opt/smartpos_backend`):**
   - Copy folder `pos_desktop/backend` to `/opt/smartpos_backend`
   - Run `dart pub get` inside `/opt/smartpos_backend`
4. **Create Environment File (`/opt/smartpos_backend/.env`):**
   ```env
   PORT=8080
   DB_HOST=192.168.1.201
   DB_PORT=3306
   DB_USER=smartpos_user
   DB_PASS=Set_Your_Secure_Password_Here
   DB_NAME=smartpos
   PUBLIC_URL=https://api.namecheap.work
   LINE_CHANNEL_TOKEN=YOUR_LINE_CHANNEL_TOKEN
   JWT_SECRET=YOUR_JWT_SECRET
   ```
5. **Configure Systemd Auto-Restart Service (`/etc/systemd/system/smartpos-backend.service`):**
   ```ini
   [Unit]
   Description=S-Mart POS Backend Server
   After=network.target

   [Service]
   Type=simple
   User=root
   WorkingDirectory=/opt/smartpos_backend
   ExecStart=/opt/dart-sdk/bin/dart bin/server.dart
   Restart=always
   RestartSec=5
   Environment=PORT=8080

   [Install]
   WantedBy=multi-user.target
   ```
   Enable and start:
   ```bash
   systemctl daemon-reload
   systemctl enable --now smartpos-backend
   systemctl status smartpos-backend
   ```

---

## 6. Phase 4: LXC 102 - Cloudflare Tunnel
### ขั้นตอนเชื่อมต่อ Cloudflare Tunnel

1. **Create LXC Container (ID: 102):**
   - Name: `cloudflare-tunnel` | OS: `Ubuntu 24.04` | Disks: `10GB` | RAM: `1024 MB`
   - Network: Static IPv4 `192.168.1.203/24`, Gateway `192.168.1.1`
2. **Install `cloudflared`:**
   ```bash
   curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
   dpkg -i cloudflared.deb
   ```
3. **Bind Existing Tunnel Token / เชื่อมต่อโทเคนเดิม:**
   ```bash
   cloudflared service install <YOUR_EXISTING_CLOUDFLARE_TUNNEL_TOKEN>
   systemctl enable --now cloudflared
   ```
   *(Ensure Cloudflare Zero Trust Dashboard routes `api.namecheap.work` to `http://192.168.1.202:8080`)*

---

## 7. Phase 5: UPS Auto-Shutdown Setup
### ติดตั้งระบบป้องกันไฟดับอัตโนมัติ

1. Connect UPS USB Data Cable to Beelink Mini PC USB Port.
2. Inside Proxmox Host Shell (`192.168.1.200`):
   - Configure `/etc/apcupsd/apcupsd.conf`:
     ```ini
     UPSCABLE usb
     UPSTYPE usb
     DEVICE
     BATTERYLEVEL 20
     MINUTES 5
     ```
   - Enable service: `systemctl enable --now apcupsd`
   - Test connection: `apcaccess status`
3. Proxmox will now automatically send graceful shutdown signals to all LXC containers and safely power down the host if electricity is out for > 5 minutes or battery < 20%.

---

## 8. Phase 6: Client Switching & Verification
### การสลับเครื่องลูกและทดสอบระบบ

1. **POS Desktop (Cashier PC หน้าร้าน):**
   - Open POS Desktop Settings -> Set **Database Host** to `192.168.1.201` (or API URL to `http://192.168.1.202:8080`).
   - Test scanning a product barcode and loading customer debt list.
2. **S-Link Mobile App (แอปพนักงานขับรถ):**
   - Test loading Job Dashboard and completing a delivery stage.
   - S-Link connects automatically through `https://api.namecheap.work` without any client update!
3. **ESP32 Fingerprint / GPS:**
   - Verify scanner syncs attendance logs with the backend.

---

## 9. Disaster Recovery & Rollback Plan
### แผนกู้คืนฉุกเฉินและย้อนกลับ

- **Proxmox Backup / สำรองทั้งระบบ:**
  - In Proxmox Web GUI -> `Datacenter` -> `Backup` -> Add Backup job to store weekly full snapshots to Cashier PC (via SMB/NFS Share).
- **Rollback Option / แผนย้อนกลับหากเกิดปัญหาฉุกเฉิน:**
  - If the new Mini PC encounters issues, change the POS Desktop settings back to `127.0.0.1` or the old server IP immediately to resume normal cashier operations with zero downtime.
