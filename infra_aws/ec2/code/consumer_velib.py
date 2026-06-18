import json
import os
import boto3
from kafka import KafkaConsumer
from decimal import Decimal

TOPIC             = "velib.realtime"
BOOTSTRAP_SERVERS = "localhost:9092"
DYNAMO_TABLE      = os.environ.get("DYNAMO_TABLE", "velib_realtime")

dynamodb = boto3.resource("dynamodb", region_name="eu-west-3")
table    = dynamodb.Table(DYNAMO_TABLE)

consumer = KafkaConsumer(
    TOPIC,
    bootstrap_servers=BOOTSTRAP_SERVERS,
    auto_offset_reset="latest",
    enable_auto_commit=True,
    value_deserializer=lambda x: json.loads(x.decode("utf-8")),
)
print("Consumer Kafka démarré — écriture vers DynamoDB:", DYNAMO_TABLE)


def to_decimal(v):
    if isinstance(v, float):
        return Decimal(str(v))
    if isinstance(v, dict):
        return {k: to_decimal(val) for k, val in v.items()}
    if isinstance(v, list):
        return [to_decimal(i) for i in v]
    return v


for msg in consumer:
    data = msg.value
    station_id = data.get("stationId")
    if not station_id:
        continue

    try:
        table.put_item(Item={
            "stationId":                   station_id,
            "timestamp":                   data.get("timestamp"),
            "num_bikes_available":         data.get("num_bikes_available"),
            "num_docks_available":         data.get("num_docks_available"),
            "mechanical":                  data.get("mechanical"),
            "ebike":                       data.get("ebike"),
            "nom_arrondissement_communes": data.get("nom_arrondissement_communes"),
            "latitude":                    to_decimal(data.get("latitude")),
            "longitude":                   to_decimal(data.get("longitude")),
        })
        print("DynamoDB update:", station_id)
    except Exception as e:
        print("Erreur DynamoDB:", e)
