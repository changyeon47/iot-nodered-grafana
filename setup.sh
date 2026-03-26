#!/bin/bash
# ============================================================
# setup.sh — IoT Node-RED & Grafana 모니터링 설치 스크립트
# ============================================================
# 실행: sudo bash setup.sh
# ============================================================

set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODERED_USER="${SUDO_USER:-$USER}"

echo -e "\n${BOLD}============================================================${NC}"
echo -e "${BOLD}  IoT Node-RED & Grafana 모니터링 — 설치${NC}"
echo -e "${BOLD}============================================================${NC}\n"

# ── [1] MySQL DB 생성 ─────────────────────────────────────
info "[1/4] MySQL 데이터베이스 설정..."
mysql -u root <<'SQL'
CREATE DATABASE IF NOT EXISTS env_monitor
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'env_user'@'localhost' IDENTIFIED BY 'env_pass123';
GRANT ALL PRIVILEGES ON env_monitor.* TO 'env_user'@'localhost';
FLUSH PRIVILEGES;
USE env_monitor;
CREATE TABLE IF NOT EXISTS sensor_data (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  location    VARCHAR(50)  NOT NULL,
  temperature DECIMAL(5,2) NOT NULL,
  humidity    DECIMAL(5,2) NOT NULL,
  co2         INT          NOT NULL,
  pm25        DECIMAL(6,2) NOT NULL,
  recorded_at TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_location    (location),
  INDEX idx_recorded_at (recorded_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
SQL
success "MySQL DB(env_monitor) 설정 완료"

# ── [2] Python pymysql ────────────────────────────────────
info "[2/4] Python pymysql 설치..."
pip3 install pymysql --quiet 2>/dev/null || true
success "pymysql 설치 완료"

# ── [3] Node-RED ──────────────────────────────────────────
info "[3/4] Node-RED 설치 및 설정..."
if ! command -v node-red &>/dev/null; then
    npm install -g --unsafe-perm node-red
fi
NODERED_HOME="$(eval echo ~${NODERED_USER})/.node-red"
sudo -u "$NODERED_USER" mkdir -p "$NODERED_HOME"
if [ ! -f "$NODERED_HOME/package.json" ]; then
    sudo -u "$NODERED_USER" bash -c "cd $NODERED_HOME && npm init -y" >/dev/null 2>&1
fi
sudo -u "$NODERED_USER" bash -c "cd $NODERED_HOME && npm install --save node-red-node-mysql node-red-dashboard 2>&1 | tail -2"
# flows.json 복사
sudo -u "$NODERED_USER" cp "$SCRIPT_DIR/nodered/flows.json" "$NODERED_HOME/flows.json"
# 크리덴셜 파일
cat > "$NODERED_HOME/flows_cred.json" <<CRED
{"db_config":{"user":"env_user","password":"env_pass123"}}
CRED
chown "$NODERED_USER:$NODERED_USER" "$NODERED_HOME/flows_cred.json"
# credentialSecret 비활성화
if grep -q '//credentialSecret' "$NODERED_HOME/settings.js" 2>/dev/null; then
    sed -i 's|//credentialSecret: "a-secret-key",|credentialSecret: false,|' "$NODERED_HOME/settings.js"
fi
success "Node-RED 설정 완료"

# ── [4] Grafana (standalone) ──────────────────────────────
info "[4/4] Grafana standalone 설치..."
GRAFANA_DIR="$(eval echo ~${NODERED_USER})/grafana-standalone"
if [ ! -f "$GRAFANA_DIR/bin/grafana-server" ] && [ ! -f "$GRAFANA_DIR/bin/grafana" ]; then
    warn "Grafana를 수동으로 설치해야 합니다:"
    warn "  wget -O /tmp/grafana.tar.gz https://dl.grafana.com/oss/release/grafana-11.5.2.linux-amd64.tar.gz"
    warn "  mkdir -p $GRAFANA_DIR && tar -xzf /tmp/grafana.tar.gz -C $GRAFANA_DIR --strip-components=1"
else
    mkdir -p "$GRAFANA_DIR/conf/provisioning/datasources"
    mkdir -p "$GRAFANA_DIR/conf/provisioning/dashboards"
    cp "$SCRIPT_DIR/grafana/datasource.yaml" "$GRAFANA_DIR/conf/provisioning/datasources/"
    cp "$SCRIPT_DIR/grafana/dashboard.json"  "$GRAFANA_DIR/conf/provisioning/dashboards/"
    sed 's|/etc/grafana/provisioning/dashboards|'"$GRAFANA_DIR/conf/provisioning/dashboards"'|g' \
        "$SCRIPT_DIR/grafana/dashboard-provisioning.yaml" \
        > "$GRAFANA_DIR/conf/provisioning/dashboards/dashboard-provisioning.yaml"
    success "Grafana 설정 완료 → $GRAFANA_DIR"
fi

echo -e "\n${BOLD}============================================================${NC}"
echo -e "${GREEN}${BOLD}  설치 완료! 아래 순서로 실행하세요:${NC}"
echo -e "${BOLD}============================================================${NC}"
echo -e "\n  1. 데이터 주입:"
echo -e "     ${YELLOW}python3 $SCRIPT_DIR/injector.py${NC}"
echo -e "\n  2. Node-RED 시작:"
echo -e "     ${YELLOW}node-red --port 1880${NC}"
echo -e "     → 대시보드: http://localhost:1880/ui"
echo -e "\n  3. Grafana 시작:"
echo -e "     ${YELLOW}~/grafana-standalone/bin/grafana server \\"
echo -e "       --config ~/grafana-standalone/conf/custom.ini \\"
echo -e "       --homepath ~/grafana-standalone${NC}"
echo -e "     → 대시보드: http://localhost:3000  (admin/admin)"
echo -e "\n${BOLD}============================================================${NC}\n"
