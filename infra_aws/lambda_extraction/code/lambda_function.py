import boto3
import requests
import os
import urllib.parse
from datetime import datetime, timedelta

s3 = boto3.client("s3")

def lambda_handler(event, context):
    TARGET_DATE = event.get("date", None)

    if TARGET_DATE:
        date_obj = datetime.strptime(TARGET_DATE, "%Y-%m-%d")
    else:
        date_obj = datetime.today() - timedelta(days=1)

    DATE_STR  = date_obj.strftime("%Y-%m-%d")
    YEAR      = date_obj.year
    MONTH     = f"{date_obj.month:02d}"
    DAY       = f"{date_obj.day:02d}"
    START     = f"{DATE_STR}T00:00:00"
    NEXT_DAY  = (date_obj + timedelta(days=1)).strftime("%Y-%m-%d")
    END       = f"{NEXT_DAY}T00:00:00"

    BUCKET = os.environ.get("BUCKET", "s3-projet-efrei")
    results = {}

    # ─────────────────────────────────────────────────────────
    # 1. QUALITÉ DE L'AIR (LCSQA / INERIS)
    # ─────────────────────────────────────────────────────────
    air_url = (
        "https://object.infra.data.gouv.fr/api/v1/buckets/ineris-prod/objects/download?prefix="
        f"lcsqa/concentrations-de-polluants-atmospheriques-reglementes/temps-reel/{YEAR}/FR_E2_{DATE_STR}.csv"
    )
    print(f"[air_quality] GET {air_url}")
    r = requests.get(air_url, timeout=60)
    if r.status_code == 200:
        key = f"bronze/air_quality/{YEAR}/{MONTH}/{DAY}/FR_E2_{DATE_STR}.csv"
        s3.put_object(Bucket=BUCKET, Key=key, Body=r.content, ContentType="text/csv")
        results["air_quality"] = f"s3://{BUCKET}/{key}"
        print(f"[air_quality] OK → {key}")
    else:
        results["air_quality"] = f"ERROR {r.status_code}"
        print(f"[air_quality] ERREUR {r.status_code}")

    # ─────────────────────────────────────────────────────────
    # 2. COMPTAGE VÉLO (opendata.paris.fr)
    # ─────────────────────────────────────────────────────────
    where_velo = urllib.parse.quote(f"date >= '{START}' AND date < '{END}'", safe="")
    velo_url = (
        "https://opendata.paris.fr/api/explore/v2.1/catalog/datasets/"
        f"comptage-velo-donnees-compteurs/exports/csv?where={where_velo}"
    )
    print(f"[velo] GET {velo_url}")
    r = requests.get(velo_url, timeout=120)
    if r.status_code == 200:
        key = f"bronze/velo_counts/{YEAR}/{MONTH}/{DAY}/comptage_velo_{DATE_STR}.csv"
        s3.put_object(Bucket=BUCKET, Key=key, Body=r.content, ContentType="text/csv")
        results["velo_counts"] = f"s3://{BUCKET}/{key}"
        print(f"[velo] OK → {key}")
    else:
        results["velo_counts"] = f"ERROR {r.status_code}"
        print(f"[velo] ERREUR {r.status_code}")

    # ─────────────────────────────────────────────────────────
    # 3. TRAFIC ROUTIER (opendata.paris.fr)
    # ─────────────────────────────────────────────────────────
    where_trafic = urllib.parse.quote(f"t_1h >= '{START}' AND t_1h < '{END}'", safe="")
    trafic_url = (
        "https://opendata.paris.fr/api/explore/v2.1/catalog/datasets/"
        f"comptages-routiers-permanents/exports/csv?where={where_trafic}"
    )
    print(f"[trafic] GET {trafic_url}")
    r = requests.get(trafic_url, timeout=120)
    if r.status_code == 200:
        key = f"bronze/traffic_counts/{YEAR}/{MONTH}/{DAY}/comptage_trafic_{DATE_STR}.csv"
        s3.put_object(Bucket=BUCKET, Key=key, Body=r.content, ContentType="text/csv")
        results["traffic_counts"] = f"s3://{BUCKET}/{key}"
        print(f"[trafic] OK → {key}")
    else:
        results["traffic_counts"] = f"ERROR {r.status_code}"
        print(f"[trafic] ERREUR {r.status_code}")

    # ─────────────────────────────────────────────────────────
    # 4. STATIONS VÉLIB (opendata.paris.fr — référentiel JSON)
    # ─────────────────────────────────────────────────────────
    stations_url = (
        "https://opendata.paris.fr/api/explore/v2.1/catalog/datasets/"
        "velib-emplacement-des-stations/exports/json"
    )
    print(f"[stations] GET {stations_url}")
    r = requests.get(stations_url, timeout=60)
    if r.status_code == 200:
        key = f"bronze/stations/{YEAR}/{MONTH}/{DAY}/stations_{DATE_STR}.json"
        s3.put_object(Bucket=BUCKET, Key=key, Body=r.content, ContentType="application/json")
        results["stations"] = f"s3://{BUCKET}/{key}"
        print(f"[stations] OK → {key}")
    else:
        results["stations"] = f"ERROR {r.status_code}"
        print(f"[stations] ERREUR {r.status_code}")

    print("====== EXTRACTION TERMINÉE ======")
    print(results)
    return {"statusCode": 200, "body": results, "date": DATE_STR}
