#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
injector.py — IoT 환경 센서 데이터 생성기
=========================================
4개 위치(실험실, 사무실, 서버실, 야외)의 환경 센서 데이터를
3초마다 MySQL DB에 삽입하는 시뮬레이터.

사용법:
    python3 injector.py

종료:
    Ctrl+C
"""

import random
import time
import math
import subprocess
from datetime import datetime

# pymysql 우선, 없으면 mysql CLI 방식 사용
try:
    import pymysql
    USE_PYMYSQL = True
except ImportError:
    USE_PYMYSQL = False

# ── DB 접속 설정 ──────────────────────────────
DB_HOST = 'localhost'
DB_USER = 'env_user'
DB_PASS = 'env_pass123'
DB_NAME = 'env_monitor'

# ── 위치별 센서 기준값 ────────────────────────
LOCATIONS = {
    '실험실': {'temp_base': 22.0, 'hum_base': 50.0, 'co2_base': 600, 'pm_base': 12.0},
    '사무실': {'temp_base': 25.0, 'hum_base': 58.0, 'co2_base': 900, 'pm_base': 18.0},
    '서버실': {'temp_base': 28.0, 'hum_base': 40.0, 'co2_base': 500, 'pm_base':  8.0},
    '야외':   {'temp_base': 18.0, 'hum_base': 65.0, 'co2_base': 415, 'pm_base': 35.0},
}

MAX_ROWS = 1000
INTERVAL = 3     # 삽입 주기 (초)


def generate_sensor_data(location, params, hour):
    """위치별 현실적인 센서값 생성 (사인파 + 가우시안 노이즈)"""
    b = params
    t = time.time()

    def noisy(base, amp, sigma, cycle=3600):
        sine = amp * math.sin(2 * math.pi * t / cycle)
        return round(base + sine + random.gauss(0, sigma), 2)

    temp = noisy(b['temp_base'], 3.0, 0.3)

    hum = noisy(b['hum_base'], 8.0, 1.0)
    hum = max(20.0, min(95.0, hum))

    co2_extra = 200 if location in ('사무실', '실험실') and 9 <= hour <= 18 else 0
    co2 = max(380, int(noisy(b['co2_base'] + co2_extra, 80, 15)))

    pm_extra = 20 if location == '야외' and (7 <= hour <= 9 or 17 <= hour <= 19) else 0
    pm = max(1.0, noisy(b['pm_base'] + pm_extra, 5.0, 1.0))

    return temp, hum, co2, pm


def run_pymysql():
    print("=" * 58)
    print("  IoT 환경 센서 데이터 주입기  (pymysql 모드)")
    print(f"  DB : {DB_NAME}@{DB_HOST}   주기 : {INTERVAL}초")
    print("=" * 58)

    conn = pymysql.connect(
        host=DB_HOST, user=DB_USER, password=DB_PASS,
        database=DB_NAME, charset='utf8mb4', autocommit=True
    )
    cursor = conn.cursor()
    cycle = 0

    try:
        while True:
            cycle += 1
            now = datetime.now()
            print(f"\n[{now.strftime('%Y-%m-%d %H:%M:%S')}] ── Cycle #{cycle} ──────────────────────────")

            for loc, params in LOCATIONS.items():
                temp, hum, co2, pm = generate_sensor_data(loc, params, now.hour)
                cursor.execute(
                    "INSERT INTO sensor_data (location,temperature,humidity,co2,pm25) "
                    "VALUES (%s,%s,%s,%s,%s)",
                    (loc, temp, hum, co2, pm)
                )
                print(f"  {loc:<4s} | 온도:{temp:6.1f}°C  습도:{hum:5.1f}%  "
                      f"CO₂:{co2:5d}ppm  PM2.5:{pm:6.1f}µg/m³")

            if cycle % 10 == 0:
                cursor.execute(
                    "DELETE FROM sensor_data WHERE id NOT IN "
                    "(SELECT id FROM (SELECT id FROM sensor_data "
                    f"ORDER BY id DESC LIMIT {MAX_ROWS}) t)"
                )
            time.sleep(INTERVAL)

    except KeyboardInterrupt:
        print("\n\n[종료] injector 중지")
    finally:
        cursor.close()
        conn.close()


def run_cli():
    print("=" * 58)
    print("  IoT 환경 센서 데이터 주입기  (mysql CLI 모드)")
    print(f"  DB : {DB_NAME}@{DB_HOST}   주기 : {INTERVAL}초")
    print("  ※ 빠른 실행: pip3 install pymysql")
    print("=" * 58)

    def sql(stmt):
        r = subprocess.run(
            ['mysql', f'-u{DB_USER}', f'-p{DB_PASS}', '-h', DB_HOST, DB_NAME, '-e', stmt],
            capture_output=True, text=True
        )
        if r.returncode != 0:
            print(f"  [SQL ERROR] {r.stderr.strip()}")
        return r.returncode == 0

    cycle = 0
    try:
        while True:
            cycle += 1
            now = datetime.now()
            print(f"\n[{now.strftime('%Y-%m-%d %H:%M:%S')}] ── Cycle #{cycle} ──────────────────────────")

            for loc, params in LOCATIONS.items():
                temp, hum, co2, pm = generate_sensor_data(loc, params, now.hour)
                if sql(f"INSERT INTO sensor_data (location,temperature,humidity,co2,pm25) "
                       f"VALUES ('{loc}',{temp},{hum},{co2},{pm});"):
                    print(f"  {loc:<4s} | 온도:{temp:6.1f}°C  습도:{hum:5.1f}%  "
                          f"CO₂:{co2:5d}ppm  PM2.5:{pm:6.1f}µg/m³")

            if cycle % 10 == 0:
                sql(f"DELETE FROM sensor_data WHERE id NOT IN "
                    f"(SELECT id FROM (SELECT id FROM sensor_data "
                    f"ORDER BY id DESC LIMIT {MAX_ROWS}) t);")

            time.sleep(INTERVAL)

    except KeyboardInterrupt:
        print("\n\n[종료] injector 중지")


if __name__ == '__main__':
    if USE_PYMYSQL:
        run_pymysql()
    else:
        run_cli()
