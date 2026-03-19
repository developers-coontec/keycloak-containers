#!/bin/bash -e

###########################
# Build/download Keycloak #
###########################

if [ "$GIT_REPO" != "" ]; then
    if [ "$GIT_BRANCH" == "" ]; then
        GIT_BRANCH="master"
    fi

    # Git and Maven are pre-installed in Dockerfile
    export M2_HOME=/opt/jboss/maven

    # Clone repository
    git clone --depth 1 https://github.com/$GIT_REPO.git -b $GIT_BRANCH /opt/jboss/keycloak-source

    # Build
    cd /opt/jboss/keycloak-source

    MASTER_HEAD=`git log -n1 --format="%H"`
    echo "Keycloak from [build]: $GIT_REPO/$GIT_BRANCH/commit/$MASTER_HEAD"

    $M2_HOME/bin/mvn -Pdistribution -pl distribution/server-dist -am -Dmaven.test.skip clean install

    cd /opt/jboss

    tar xfz /opt/jboss/keycloak-source/distribution/server-dist/target/keycloak-*.tar.gz

    # Remove temporary files (Maven cache ~/.m2 is preserved via BuildKit cache mount)
    rm -rf /opt/jboss/maven
    rm -rf /opt/jboss/keycloak-source

    mv /opt/jboss/keycloak-* /opt/jboss/keycloak
else
    echo "Keycloak from [download]: $KEYCLOAK_DIST"

    cd /opt/jboss/
    curl -fL $KEYCLOAK_DIST | tar zx
    mv /opt/jboss/keycloak-* /opt/jboss/keycloak
fi

#####################
# Create DB modules #
#####################

# Helper: copy from cache if exists, otherwise download and store in cache
# /opt/jboss/jdbc-cache is persisted on the host via BuildKit --mount=type=cache
JDBC_CACHE_DIR=/opt/jboss/jdbc-cache
mkdir -p $JDBC_CACHE_DIR

download_jdbc() {
    local url=$1
    local dest=$2
    local cache_file="$JDBC_CACHE_DIR/$(basename $dest)"

    if [ -f "$cache_file" ]; then
        echo "Using cached JDBC: $(basename $dest)"
        cp "$cache_file" "$dest"
    else
        echo "Downloading JDBC: $url"
        curl -fL "$url" -o "$dest"
        cp "$dest" "$cache_file"
    fi
}

mkdir -p /opt/jboss/keycloak/modules/system/layers/base/com/mysql/jdbc/main
cd /opt/jboss/keycloak/modules/system/layers/base/com/mysql/jdbc/main
download_jdbc "https://repo1.maven.org/maven2/mysql/mysql-connector-java/$JDBC_MYSQL_VERSION/mysql-connector-java-$JDBC_MYSQL_VERSION.jar" \
    "mysql-connector-java-$JDBC_MYSQL_VERSION.jar"
cp /opt/jboss/tools/databases/mysql/module.xml .
sed "s/JDBC_MYSQL_VERSION/$JDBC_MYSQL_VERSION/" /opt/jboss/tools/databases/mysql/module.xml > module.xml

mkdir -p /opt/jboss/keycloak/modules/system/layers/base/org/postgresql/jdbc/main
cd /opt/jboss/keycloak/modules/system/layers/base/org/postgresql/jdbc/main
download_jdbc "https://repo1.maven.org/maven2/org/postgresql/postgresql/$JDBC_POSTGRES_VERSION/postgresql-$JDBC_POSTGRES_VERSION.jar" \
    "postgres-jdbc.jar"
cp /opt/jboss/tools/databases/postgres/module.xml .

mkdir -p /opt/jboss/keycloak/modules/system/layers/base/org/mariadb/jdbc/main
cd /opt/jboss/keycloak/modules/system/layers/base/org/mariadb/jdbc/main
download_jdbc "https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/$JDBC_MARIADB_VERSION/mariadb-java-client-$JDBC_MARIADB_VERSION.jar" \
    "mariadb-jdbc.jar"
cp /opt/jboss/tools/databases/mariadb/module.xml .

mkdir -p /opt/jboss/keycloak/modules/system/layers/base/com/oracle/jdbc/main
cd /opt/jboss/keycloak/modules/system/layers/base/com/oracle/jdbc/main
cp /opt/jboss/tools/databases/oracle/module.xml .

mkdir -p /opt/jboss/keycloak/modules/system/layers/keycloak/com/microsoft/sqlserver/jdbc/main
cd /opt/jboss/keycloak/modules/system/layers/keycloak/com/microsoft/sqlserver/jdbc/main
download_jdbc "https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/$JDBC_MSSQL_VERSION/mssql-jdbc-$JDBC_MSSQL_VERSION.jar" \
    "mssql-jdbc.jar"
cp /opt/jboss/tools/databases/mssql/module.xml .

######################
# Configure Keycloak #
######################

cd /opt/jboss/keycloak
chmod a+x bin/jboss-cli.sh

bin/jboss-cli.sh --file=/opt/jboss/tools/cli/standalone-configuration.cli
rm -rf /opt/jboss/keycloak/standalone/configuration/standalone_xml_history

bin/jboss-cli.sh --file=/opt/jboss/tools/cli/standalone-ha-configuration.cli
rm -rf /opt/jboss/keycloak/standalone/configuration/standalone_xml_history

###########
# Garbage #
###########

rm -rf /opt/jboss/keycloak/standalone/tmp/auth
rm -rf /opt/jboss/keycloak/domain/tmp/auth

###################
# Set permissions #
###################

echo "jboss:x:0:root" >> /etc/group
echo "jboss:x:1000:0:JBoss user:/opt/jboss:/sbin/nologin" >> /etc/passwd
chown -R jboss:root /opt/jboss
chmod -R g+rwX /opt/jboss
