# IoT 실시간 모니터링 — Node-RED & Grafana

MySQL에 저장된 IoT 환경 센서 데이터를 **Node-RED**와 **Grafana** 두 가지 대시보드로 실시간 시각화하는 시스템입니다.

---

## 1. 프로젝트 개요

| 구성 요소 | 역할 |
|-----------|------|
| `injector.py` | Python — 3초마다 가상 센서 데이터 생성 → MySQL INSERT |
| MySQL | 시계열 센서 데이터 저장소 (`env_monitor.sensor_data`) |
| **Node-RED** | 플로우 기반 실시간 게이지·차트 대시보드 (port 1880) |
| **Grafana** | 전문 시계열 모니터링 대시보드 (port 3000) |

---

## 2. 전체 시스템 블록도

```mermaid
flowchart TD
    subgraph Gen["데이터 생성"]
        PY["injector.py\n(Python 3)\n사인파+노이즈\n3초 주기"]
    end

    subgraph DB["데이터 저장"]
        MYSQL[("MySQL 8.0\nenv_monitor\nsensor_data")]
    end

    subgraph NR["Node-RED 대시보드\nlocalhost:1880/ui"]
        NR_INJ["Inject\n3초 트리거"]
        NR_FN1["Function\nSQL 설정"]
        NR_SQL["MySQL Node\nSELECT"]
        NR_FN2["Function\n파싱·분배"]
        NR_G["Gauge ×4\n온도·습도·CO₂·PM2.5"]
        NR_C["Chart ×4\n시계열 추이"]
        NR_T["Template\n기록 테이블"]
    end

    subgraph GF["Grafana 대시보드\nlocalhost:3000"]
        GF_DS["MySQL Datasource"]
        GF_DB["Dashboard\n게이지+시계열+테이블\n5초 자동갱신"]
    end

    PY -->|"INSERT 3초마다"| MYSQL

    MYSQL -->|SELECT| NR_SQL
    NR_INJ --> NR_FN1 --> NR_SQL
    NR_SQL --> NR_FN2
    NR_FN2 --> NR_G
    NR_FN2 --> NR_C
    NR_SQL --> NR_T

    MYSQL -->|"5초마다 자동쿼리"| GF_DS --> GF_DB

    Browser1["브라우저"] -->|"HTTP :1880/ui"| NR_G
    Browser2["브라우저"] -->|"HTTP :3000"| GF_DB
```

---

## 3. Node-RED 플로우 구조

```mermaid
flowchart LR
    INJ["Inject\n3초"] --> F1["Function\n쿼리:최신값\nmsg.topic=SQL"]
    INJ --> F2["Function\n쿼리:최근기록\nmsg.topic=SQL"]

    F1 --> SQL1["MySQL\n최신값"]
    F2 --> SQL2["MySQL\n최근기록"]

    SQL1 --> P1["Function\n게이지분배\n4개출력"]
    SQL1 --> P2["Function\n차트분배\n4개출력"]
    SQL2 --> P3["Function\nHTML포맷"]

    P1 --> G1["Gauge 온도"]
    P1 --> G2["Gauge 습도"]
    P1 --> G3["Gauge CO₂"]
    P1 --> G4["Gauge PM2.5"]

    P2 --> C1["Chart 온도"]
    P2 --> C2["Chart 습도"]
    P2 --> C3["Chart CO₂"]
    P2 --> C4["Chart PM2.5"]

    P3 --> T["Template\n테이블"]
```

---

## 4. 데이터베이스 스키마

| 컬럼 | 타입 | 설명 |
|------|------|------|
| `id` | INT AUTO_INCREMENT PK | 고유 식별자 |
| `location` | VARCHAR(50) | 측정 위치 (실험실/사무실/서버실/야외) |
| `temperature` | DECIMAL(5,2) | 온도 °C |
| `humidity` | DECIMAL(5,2) | 습도 % |
| `co2` | INT | CO₂ ppm |
| `pm25` | DECIMAL(6,2) | PM2.5 µg/m³ |
| `recorded_at` | TIMESTAMP | 기록 시각 |

---

## 5. 파일 구조

```
iot-nodered-grafana/
├── injector.py              # Python 센서 데이터 생성기
├── nodered/
│   └── flows.json           # Node-RED 플로우 정의
├── grafana/
│   ├── datasource.yaml      # MySQL 데이터소스 프로비저닝
│   ├── dashboard-provisioning.yaml
│   └── dashboard.json       # Grafana 대시보드 정의
├── setup.sh                 # 자동 설치 스크립트
├── process.md               # 이 파일 (Mermaid 블록도 포함)
└── README.md                # 사용 설명서
```

---

## 6. 실행 방법

### 1단계: 설치
```bash
sudo bash setup.sh
```

### 2단계: 데이터 주입
```bash
python3 injector.py
```

### 3단계: Node-RED 시작
```bash
node-red --port 1880
# → http://localhost:1880/ui
```

### 4단계: Grafana 시작
```bash
~/grafana-standalone/bin/grafana server \
  --config ~/grafana-standalone/conf/custom.ini \
  --homepath ~/grafana-standalone
# → http://localhost:3000  (admin / admin)
```
