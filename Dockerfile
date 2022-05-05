FROM flink:1.14.0-scala_2.12-java8

ENV FLINK_VERSION 1.14.0
ENV JAVA_VERSION java8
ENV KAFKA_CLIENTS_VERSION 7.1.1
ENV PYTHON_VERSION 3.8.13
ENV SCALA_VERSION 2.12

# Post install script (cleanups)
ADD ./dkr_flink/post-install /root/

# Install Dependencies
RUN set -ex && \
  apt-get update -qq && \
  apt-get install -y \
  bash build-essential zlib1g-dev libncurses5-dev \
  libgdbm-dev libnss3-dev libssl-dev \
  libsqlite3-dev libreadline-dev libffi-dev \
  curl libbz2-dev && \
  /root/post-install

# Install Python
RUN set -ex && \
    curl -O https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz && \
    tar -xf Python-${PYTHON_VERSION}.tar.xz && \
    cd Python-${PYTHON_VERSION} && \
    ./configure --enable-optimizations && make && make install && \
    cd .. && rm -rf Python-${PYTHON_VERSION} && \
    ln -s /usr/local/bin/python3 /usr/bin/python && \
    /root/post-install

# Grab gosu for easy step-down from root
ENV GOSU_VERSION 1.11
RUN set -ex; \
  wget -nv -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)"; \
  wget -nv -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc"; \
  export GNUPGHOME="$(mktemp -d)"; \
  for server in ha.pool.sks-keyservers.net $(shuf -e \
                          hkp://p80.pool.sks-keyservers.net:80 \
                          keyserver.ubuntu.com \
                          hkp://keyserver.ubuntu.com:80 \
                          pgp.mit.edu) ; do \
      gpg --batch --keyserver "$server" --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && break || : ; \
  done && \
  gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
  gpgconf --kill all; \
  rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
  chmod +x /usr/local/bin/gosu; \
  gosu nobody true

# Install PyFlink
RUN python -m pip install --user --no-cache apache-flink==${FLINK_VERSION}
RUN python -m pip install --user --no-cache pyflink

## Add connectors
RUN mkdir -p /opt/flink/lib/
RUN curl --output /opt/flink/lib/flink-sql-avro-confluent-registry-${FLINK_VERSION}.jar https://repo1.maven.org/maven2/org/apache/flink/flink-sql-avro-confluent-registry/${FLINK_VERSION}/flink-sql-avro-confluent-registry-${FLINK_VERSION}.jar 
RUN curl --output /opt/flink/lib/flink-sql-connector-kafka_${SCALA_VERSION}-${FLINK_VERSION}.jar https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka_${SCALA_VERSION}/${FLINK_VERSION}/flink-sql-connector-kafka_${SCALA_VERSION}-${FLINK_VERSION}.jar 

# Connector from Confluent
RUN curl --output /opt/flink/lib/kafka-clients-${KAFKA_CLIENTS_VERSION}-ccs.jar https://packages.confluent.io/maven/org/apache/kafka/kafka-clients/${KAFKA_CLIENTS_VERSION}-ccs/kafka-clients-${KAFKA_CLIENTS_VERSION}-ccs.jar 

# Configure container
COPY ./dkr_flink/docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
EXPOSE 6123 8081
CMD ["help"]
