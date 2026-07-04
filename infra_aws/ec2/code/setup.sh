#!/bin/bash
set -e

# ── Dépendances système ──────────────────────────────────────────────────────
apt-get update -y
apt-get install -y default-jre python3 python3-pip python3-venv wget curl

# ── Kafka 3.5.1 ─────────────────────────────────────────────────────────────
cd /tmp
wget -q https://mirrors.huaweicloud.com/apache/kafka/3.5.1/kafka_2.13-3.5.1.tgz -O kafka.tgz
mkdir -p /opt/kafka
tar -xzf kafka.tgz --strip-components=1 -C /opt/kafka
echo 'export PATH=$PATH:/opt/kafka/bin' >> /home/ubuntu/.bashrc

# Réduire le heap JVM pour t2.micro (1GB RAM total)
export KAFKA_HEAP_OPTS="-Xmx256m -Xms128m"

# ── Venv Python ─────────────────────────────────────────────────────────────
python3 -m venv /opt/velib_env
/opt/velib_env/bin/pip install --upgrade pip
/opt/velib_env/bin/pip install kafka-python requests boto3

# ── Téléchargement des scripts depuis S3 ────────────────────────────────────
S3_BUCKET="${S3_BUCKET:-s3-projet-efrei}"
aws s3 cp s3://${S3_BUCKET}/ec2/producer_velib.py /opt/producer_velib.py
aws s3 cp s3://${S3_BUCKET}/ec2/consumer_velib.py /opt/consumer_velib.py

# ── Démarrage Zookeeper + Kafka ──────────────────────────────────────────────
KAFKA_HEAP_OPTS="-Xmx128m -Xms64m" \
nohup /opt/kafka/bin/zookeeper-server-start.sh \
    /opt/kafka/config/zookeeper.properties > /tmp/zookeeper.log 2>&1 &
sleep 10

KAFKA_HEAP_OPTS="-Xmx256m -Xms128m" \
nohup /opt/kafka/bin/kafka-server-start.sh \
    /opt/kafka/config/server.properties > /tmp/kafka.log 2>&1 &
sleep 15

# ── Création du topic ────────────────────────────────────────────────────────
/opt/kafka/bin/kafka-topics.sh \
    --create \
    --if-not-exists \
    --bootstrap-server localhost:9092 \
    --replication-factor 1 \
    --partitions 1 \
    --topic velib.realtime

# ── Démarrage producer + consumer ───────────────────────────────────────────
DYNAMO_TABLE="${DYNAMO_TABLE:velib_realtime}"

nohup /opt/velib_env/bin/python /opt/producer_velib.py \
    > /tmp/producer.log 2>&1 &

nohup env DYNAMO_TABLE=${DYNAMO_TABLE} \
    /opt/velib_env/bin/python /opt/consumer_velib.py \
    > /tmp/consumer.log 2>&1 &

echo "Setup terminé — Kafka + producer + consumer démarrés"