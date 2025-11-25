#!/bin/bash

# Configuration
RANDOM_MSG="msg-$(date +%s)-$RANDOM"
TOPIC_NAME="test-hello"
BOOTSTRAP="localhost:9092"

KAFKA_VERSION="4.1.1"
SCALA_VERSION="2.13"

KAFKA_URL="https://dlcdn.apache.org/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"
KAFKA_DIR="./kafka_${SCALA_VERSION}-${KAFKA_VERSION}"

# Download Kafka if not already present
if [ ! -d "${KAFKA_DIR}" ]; then
  echo "Downloading Kafka ${KAFKA_VERSION}..."
  curl -L "$KAFKA_URL" | tar xz
fi

# Check if port-forward is running
if ! nc -z localhost 9092 2>/dev/null; then
  echo "ERROR: Kafka is not accessible on localhost:9092"
  echo "Please run port-forward in another terminal:"
  echo "  kubectl port-forward -n confluent kafka-0 9092:9092"
  exit 1
fi

# kubectl get secret ca-pair-sslcerts -n confluent -o jsonpath='{.data.tls\.crt}' | base64 -d > producer/ca.crt
# Produce message
echo "Producing message: ${RANDOM_MSG}"
echo "${RANDOM_MSG}" | "${KAFKA_DIR}/bin/kafka-console-producer.sh" \
  --bootstrap-server "${BOOTSTRAP}" \
  --topic "${TOPIC_NAME}" \
  --producer.config "./client.properties"