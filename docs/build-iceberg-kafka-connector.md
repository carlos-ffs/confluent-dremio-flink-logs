
# Build Iceberg Kafka Connector (Optional)

We need to build a custom version of the Iceberg Kafka connector that includes the [Dremio Auth Manager](https://github.com/dremio/iceberg-auth-manager) for OAuth2 authentication with Dremio Catalog. The connector must contain the Dremio Auth Manager JAR in its `lib/` directory.

> [!NOTE]
> A pre-built connector is already configured and will be automatically downloaded by Kafka Connect. However, in the future, the pre-build connector might be deleted from the S3 bucket. You need to build the connector yourself if you want to:
> - Use a different version of Apache Iceberg
> - Customize the connector
> - Use a different version of Dremio Auth Manager


## Prerequisites for Building

- **Java**: JDK 17, or 21 (the script defaults to JDK 21)
- **Maven**: For downloading dependencies
- **Build tools**: `git`, `unzip`, `zip`

## 1. Build the Connector

Run the build script:

```bash
./scripts/build-iceberg-kafka-connector.sh
```

The script performs the following steps:

1. **Clones Apache Iceberg**
   - Creates a working directory: `./iceberg-kafka-connector-build/`
   - Clones from: `https://github.com/apache/iceberg.git`
   - Optional: Uncomment line 35 to checkout a specific release tag

2. **Builds Iceberg Kafka Connect Runtime**
   - Uses Gradle to build only the Kafka Connect module
   - Skips tests for faster build (typically 5-10 minutes)
   - Output: `iceberg-kafka-connect-runtime-*.zip`

3. **Downloads Dremio Auth Manager**
   - Version: `0.1.3` (configurable via `AUTHMGR_VERSION` variable)
   - Downloads from Maven Central: `com.dremio.iceberg.authmgr:authmgr-oauth2-runtime`
   - Stored in: `~/.m2/repository/`

4. **Bundles Components**
   - Extracts the Iceberg connector ZIP
   - Adds the Auth Manager JAR to the `lib/` directory
   - Re-packages into: `iceberg-kafka-connect-with-authmgr-0.1.3.zip`

5. **Outputs Build Information**
   - Final ZIP location: `./iceberg-kafka-connector-build/iceberg-kafka-connect-with-authmgr-0.1.3.zip`
   - SHA-512 checksum for verification
   - Confirms Auth Manager JAR is included

## 2. Setup Custom Connector

After building, you need to make the connector available to Kafka Connect:

1. **Upload the ZIP file** to a location accessible from your Kubernetes cluster:
   ```bash
   # Example: Upload to S3
   aws s3 cp ./iceberg-kafka-connector-build/iceberg-kafka-connect-with-authmgr-0.1.3.zip \
     s3://your-bucket/connectors/

   # Get the public URL
   aws s3 presign s3://your-bucket/connectors/iceberg-kafka-connect-with-authmgr-0.1.3.zip
   ```

2. **Update the connector configuration** in `charts/confluent-resources/templates/confluent-platform-quick.yaml`:
   ```yaml
   # Around line 170-173
   build:
     type: onDemand
     onDemand:
       plugins:
         url:
           - archivePath: https://your-url/iceberg-kafka-connect-with-authmgr-0.1.3.zip
             checksum: <your-sha512-checksum>
             name: iceberg-kafka-connect-with-authmgr-0.1.3
   ```

3. **Commit and push** the changes - ArgoCD will automatically sync and redeploy Kafka Connect with your custom connector.

> [!IMPORTANT] 
> Your uploaded ZIP file URL must end with `.zip` for Confluent Kafka Connect to recognize it as a plugin archive.

## Troubleshooting Build Issues

**Java version errors**:
```bash
# Check Java version
java -version

# On macOS, list available Java versions
/usr/libexec/java_home -V

# Set JAVA_HOME manually before running script
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
```

**Gradle build failures**:
- Ensure you have sufficient memory (4GB+ recommended)
- Check internet connection for downloading dependencies
- Try cleaning the build: `cd iceberg-kafka-connector-build/iceberg && ./gradlew clean`

**Maven download failures**:
- Verify Maven is installed: `mvn --version`
- Check Maven Central is accessible
- Clear Maven cache: `rm -rf ~/.m2/repository/com/dremio/iceberg/authmgr/`
