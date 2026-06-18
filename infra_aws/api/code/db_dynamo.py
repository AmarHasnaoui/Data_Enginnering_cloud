import os
import boto3
from decimal import Decimal
from boto3.dynamodb.conditions import Attr

# Connexion réutilisée entre les invocations Lambda (warm start)
_table = None


def get_table():
    global _table
    if _table is None:
        dynamodb = boto3.resource("dynamodb")
        _table = dynamodb.Table(os.environ.get("DYNAMO_TABLE", "velib_realtime"))
    return _table


def _clean(item: dict) -> dict:
    return {k: (float(v) if isinstance(v, Decimal) else v) for k, v in item.items()}


def get_station(station_id: str) -> dict | None:
    resp = get_table().get_item(Key={"stationId": station_id})
    item = resp.get("Item")
    return _clean(item) if item else None


def list_stations(arrondissement: str | None = None, limit: int = 1500) -> list[dict]:
    table = get_table()
    scan_kwargs = {}
    if arrondissement:
        scan_kwargs["FilterExpression"] = Attr("nom_arrondissement_communes").eq(arrondissement)

    items = []
    resp = table.scan(**scan_kwargs)
    items.extend(resp.get("Items", []))
    while "LastEvaluatedKey" in resp:
        resp = table.scan(ExclusiveStartKey=resp["LastEvaluatedKey"], **scan_kwargs)
        items.extend(resp.get("Items", []))

    return [_clean(item) for item in items[:limit]]
