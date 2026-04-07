# syntax=docker/dockerfile:1
FROM registry.access.redhat.com/ubi8-minimal

ENV KEYCLOAK_VERSION 14.0.0
ENV JDBC_POSTGRES_VERSION 42.2.5
ENV JDBC_MYSQL_VERSION 8.0.22
ENV JDBC_MARIADB_VERSION 2.5.4
ENV JDBC_MSSQL_VERSION 8.2.2.jre11

ENV LAUNCH_JBOSS_IN_BACKGROUND 1
ENV PROXY_ADDRESS_FORWARDING false
ENV JBOSS_HOME /opt/jboss/keycloak
ENV LANG en_US.UTF-8

USER root

# Layer 1: OS packages + git (cached unless base image changes)
RUN microdnf update -y && microdnf install -y glibc-langpack-en gzip hostname java-11-openjdk-headless tzdata-java openssl tar which git && microdnf clean all

# Layer 2: Download Maven (cached unless Maven version changes)
RUN mkdir -p /opt/jboss && \
    curl -fL https://archive.apache.org/dist/maven/maven-3/3.8.8/binaries/apache-maven-3.8.8-bin.tar.gz | tar xz -C /opt/jboss && \
    mv /opt/jboss/apache-maven-3.8.8 /opt/jboss/maven

# ARG는 여기에 선언해야 위의 레이어 캐시가 GIT_REPO/GIT_BRANCH 변경에 영향받지 않음
ARG GIT_REPO
ARG GIT_BRANCH
ARG KEYCLOAK_DIST=https://github.com/keycloak/keycloak/releases/download/$KEYCLOAK_VERSION/keycloak-$KEYCLOAK_VERSION.tar.gz

ADD tools /opt/jboss/tools

ARG CACHE_BUST

# --mount=type=cache: 빌드 컨테이너 밖 호스트에 캐시 유지 (빌드마다 재다운로드 없음)
RUN --mount=type=cache,target=/root/.m2,sharing=locked \
    --mount=type=cache,target=/opt/jboss/jdbc-cache,sharing=locked \
    /opt/jboss/tools/build-keycloak.sh

USER 1000

EXPOSE 8080
EXPOSE 8443

ENTRYPOINT [ "/opt/jboss/tools/docker-entrypoint.sh" ]

CMD ["-b", "0.0.0.0"]
