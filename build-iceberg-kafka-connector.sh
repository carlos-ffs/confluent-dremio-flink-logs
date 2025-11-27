#!/usr/bin/env bash
set -euo pipefail

# --- Prereqs (Linux/macOS): git, Java 17+, Maven, unzip, zip ---
# On Debian/Ubuntu: sudo apt-get install -y git unzip zip maven
# Ensure JAVA_HOME points to JDK 17+.

# Version configuration
# https://github.com/dremio/iceberg-auth-manager/releases
AUTHMGR_VERSION="0.1.3"

# Set JAVA_HOME to JDK 21 (required by Iceberg build - must be 11, 17, or 21)
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  export JAVA_HOME=$(/usr/libexec/java_home -v 21)
else
  # Linux - adjust path as needed
  export JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk}
fi
echo "Using Java: $JAVA_HOME"
java -version

# ===== 1) Get Apache Iceberg and build the Kafka Connect runtime ZIP =====
WORKDIR="${PWD}/iceberg-kafka-connector-build"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Clone Iceberg (or comment these two lines if you already have a checkout)
if [ ! -d iceberg ]; then
  git clone https://github.com/apache/iceberg.git
fi
cd iceberg

# OPTIONAL: checkout a specific release tag (uncomment and set if you want)
# git checkout apache-iceberg-1.5.0

# Build only the Kafka Connect runtime distribution (skip tests to go fast)
./gradlew :iceberg-kafka-connect:iceberg-kafka-connect-runtime:clean :iceberg-kafka-connect:iceberg-kafka-connect-runtime:build -x test -x integrationTest

# Locate the produced ZIP (there may be variants; we take the first)
DIST_DIR="kafka-connect/kafka-connect-runtime/build/distributions"
ICEBERG_ZIP="$(ls -1 "${DIST_DIR}"/iceberg-kafka-connect-runtime-*.zip | head -n1)"
echo "Found Iceberg Kafka Connect ZIP: ${ICEBERG_ZIP}"

# Fetch Dremio AuthManager runtime bundle from Maven
mvn -q dependency:get -Dartifact=com.dremio.iceberg.authmgr:authmgr-oauth2-runtime:${AUTHMGR_VERSION}
AUTHMGR_JAR="${HOME}/.m2/repository/com/dremio/iceberg/authmgr/authmgr-oauth2-runtime/${AUTHMGR_VERSION}/authmgr-oauth2-runtime-${AUTHMGR_VERSION}.jar"
test -f "$AUTHMGR_JAR" || { echo "AuthManager jar not found at $AUTHMGR_JAR"; exit 1; }
echo "Fetched AuthManager jar: ${AUTHMGR_JAR}"

# Unzip, add AuthManager jar into libs/, and re-zip
TMP_DIR="${WORKDIR}/tmp-iceberg-conn"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
unzip -q "$ICEBERG_ZIP" -d "$TMP_DIR"

# The extracted folder name starts with apache-iceberg-kafka-connect-runtime-*
EXTRACTED_DIR="$(find "$TMP_DIR" -maxdepth 1 -type d -name 'iceberg-kafka-connect-runtime-*' | head -n1)"
LIBS_DIR="${EXTRACTED_DIR}/lib"
test -d "$LIBS_DIR" || { echo "lib/ directory not found under ${EXTRACTED_DIR}"; exit 1; }

# Copy the AuthManager runtime bundle into the plugin's libs
cp "$AUTHMGR_JAR" "$LIBS_DIR"

# Make a final bundled zip
FINAL_ZIP="${WORKDIR}/iceberg-kafka-connect-with-authmgr-${AUTHMGR_VERSION}.zip"
rm -f "$FINAL_ZIP"
(
  cd "$TMP_DIR"
  zip -qr "$FINAL_ZIP" "$(basename "$EXTRACTED_DIR")"
)
echo "Created bundled plugin: ${FINAL_ZIP}"

echo "sha512sum checksum: $(sha512sum "$FINAL_ZIP")"

# Verify jar presence inside the new ZIP
unzip -l "$FINAL_ZIP" | grep -E "authmgr-oauth2-runtime-${AUTHMGR_VERSION}\.jar" || {
  echo "Warning: AuthManager jar not found in listing. Inspect ${FINAL_ZIP} manually."
}

rm -rf "$TMP_DIR"
rm -rf "$WORKDIR/iceberg"