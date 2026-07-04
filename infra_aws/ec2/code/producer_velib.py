import json
import time
import requests
from kafka import KafkaProducer
from datetime import datetime

KAFKA_BROKER = "localhost:9092"
TOPIC        = "velib.realtime"
BASE_URL     = "https://opendata.paris.fr/api/explore/v2.1/catalog/datasets/velib-disponibilite-en-temps-reel/records"
LIMIT        = 100
INTERVAL     = 300  # 5 minutes entre chaque cycle

producer = KafkaProducer(
    bootstrap_servers=KAFKA_BROKER,
    value_serializer=lambda v: json.dumps(v).encode("utf-8"),
)
print("Producer Kafka connecté — topic:", TOPIC)

while True:
    offset      = 0
    total_sent  = 0
    timestamp   = datetime.utcnow().isoformat()

    try:
        while True:
            resp = requests.get(f"{BASE_URL}?limit={LIMIT}&offset={offset}", timeout=10)
            resp.raise_for_status()
            records = resp.json().get("results", [])
            if not records:
                break

            for station in records:
                coord = station.get("coordonnees_geo") or {}
                producer.send(TOPIC, {
                    "stationId":                    station.get("stationcode"),
                    "timestamp":                    timestamp,
                    "num_bikes_available":          station.get("numbikesavailable"),
                    "num_docks_available":          station.get("numdocksavailable"),
                    "mechanical":                   station.get("mechanical"),
                    "ebike":                        station.get("ebike"),
                    "nom_arrondissement_communes":  station.get("nom_arrondissement_communes"),
                    "latitude":                     coord.get("lat"),
                    "longitude":                    coord.get("lon"),
                })
                total_sent += 1

            producer.flush()
            print(f"Lot offset={offset} → {len(records)} messages (total={total_sent})")
            offset += LIMIT

        print(f"Cycle terminé — {total_sent} messages envoyés à {timestamp}")

    except Exception as e:
        print("Erreur producer:", e)

    time.sleep(INTERVAL)
