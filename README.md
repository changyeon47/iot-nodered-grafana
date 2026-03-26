# IoT 실시간 모니터링 — Node-RED & Grafana

MySQL에 저장된 IoT 환경 센서 데이터(온도·습도·CO₂·PM2.5)를
**Node-RED**와 **Grafana** 두 가지 대시보드로 실시간 모니터링합니다.

---

## 대시보드 URL

| 대시보드 | URL | 로그인 |
|----------|-----|--------|
| Node-RED UI | http://localhost:1880/ui | 없음 |
| Grafana | http://localhost:3000 | admin / admin |

---

## 설치

```bash
sudo bash setup.sh
```

자동 설치 항목:
- MySQL DB/테이블 생성 (`env_monitor.sensor_data`)
- Node-RED + `node-red-node-mysql` + `node-red-dashboard`
- `flows.json` → `~/.node-red/flows.json` 복사
- Grafana provisioning 설정

---

## 실행

터미널 3개에서 각각 실행:

```bash
# 1. 데이터 주입 (3초마다 4개 위치 센서 데이터 생성)
python3 injector.py

# 2. Node-RED
node-red --port 1880

# 3. Grafana
~/grafana-standalone/bin/grafana server \
  --config ~/grafana-standalone/conf/custom.ini \
  --homepath ~/grafana-standalone
```

---

## 파일 구조

```
iot-nodered-grafana/
├── injector.py              # Python 센서 데이터 생성기
├── nodered/flows.json       # Node-RED 플로우 (게이지·차트·테이블)
├── grafana/
│   ├── datasource.yaml      # MySQL 데이터소스 설정
│   ├── dashboard-provisioning.yaml
│   └── dashboard.json       # 대시보드 정의
├── setup.sh                 # 통합 설치 스크립트
├── process.md               # 프로젝트 문서 (Mermaid 블록도)
└── README.md                # 이 파일
```
