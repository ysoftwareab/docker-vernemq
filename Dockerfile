# FROM debian:stretch-slim
# https://github.com/vernemq/vernemq/issues/1421#issuecomment-609467559
FROM erlang:22-slim
ARG VERNEMQ_VERSION=1.10.3

RUN apt-get update && \
    apt-get -y install bash procps openssl iproute2 curl jq libsnappy-dev net-tools nano

# https://github.com/vernemq/vernemq/issues/1421#issuecomment-609467559
RUN apt-get -y install build-essential git gnupg2 libssl-dev
RUN git config --global url."https://github".insteadOf git://github

RUN rm -rf /var/lib/apt/lists/* && \
    addgroup --gid 10000 vernemq && \
    adduser --uid 10000 --system --ingroup vernemq --home /vernemq --disabled-password vernemq

# WORKDIR /vernemq
# https://github.com/vernemq/vernemq/issues/1421#issuecomment-609467559
RUN git clone --depth 1 --branch $VERNEMQ_VERSION --branch master https://github.com/vernemq/vernemq.git vernemq-src
# RUN git clone --branch master https://github.com/erlio/vernemq.git vernemq-src
WORKDIR /vernemq-src
# RUN git reset --hard d6644aed5b83204412ce8f85ce510b2becaee2a5

# Defaults
ENV DOCKER_VERNEMQ_KUBERNETES_LABEL_SELECTOR="app=vernemq" \
    DOCKER_VERNEMQ_LOG__CONSOLE=console \
    PATH="/vernemq/bin:$PATH" \
    VERNEMQ_VERSION="$VERNEMQ_VERSION"

# BEGIN https://github.com/vernemq/vernemq/issues/1421#issuecomment-609467559
# ugly hack
RUN make rpi32 || true
WORKDIR /vernemq-src/_build/rpi32/lib/eleveldb/c_src
RUN rm -rf snappy-1.0.4 && tar -xzf snappy-1.0.4.tar.gz
# COPY files/config.guess snappy-1.0.4/config.guess
# COPY files/config.sub
RUN curl --output snappy-1.0.4/config.guess 'https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD'
RUN curl -output snappy-1.0.4/config.sub 'https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD'
RUN tar cfvz snappy-1.0.4.tar.gz snappy-1.0.4 && rm -rf snappy-1.0.4
WORKDIR /vernemq-src

# ugly hack 2
RUN make rpi32 || true
WORKDIR /vernemq-src/_build/rpi32/lib/eleveldb/c_src/leveldb
RUN rm build_config.mk && \
    sed -i'' -e 's/cstdatomic/atomic/' build_detect_platform port/atomic_pointer.h && \
    sed -i'' -e 's/.*moved below/#include <atomic>/' port/atomic_pointer.h
WORKDIR /vernemq-src

RUN make rpi32 && \
    mv -v _build/rpi32/rel/vernemq/* /vernemq/

WORKDIR /vernemq
RUN rm -rf /vernemq-src /root/.cache/rebar3
# END https://github.com/vernemq/vernemq/issues/1421#issuecomment-609467559

COPY --chown=10000:10000 bin/vernemq.sh /usr/sbin/start_vernemq
COPY --chown=10000:10000 files/vm.args /vernemq/etc/vm.args

# https://github.com/vernemq/vernemq/issues/1421#issuecomment-609467559
# ADD https://github.com/vernemq/vernemq/releases/download/$VERNEMQ_VERSION/vernemq-$VERNEMQ_VERSION.stretch.tar.gz /tmp

# RUN curl -L https://github.com/vernemq/vernemq/releases/download/$VERNEMQ_VERSION/vernemq-$VERNEMQ_VERSION.stretch.tar.gz -o /tmp/vernemq-$VERNEMQ_VERSION.stretch.tar.gz && \
#   tar -xzvf /tmp/vernemq-$VERNEMQ_VERSION.stretch.tar.gz && \
#   rm /tmp/vernemq-$VERNEMQ_VERSION.stretch.tar.gz \
# https://github.com/vernemq/vernemq/issues/1421#issuecomment-609467559
RUN chown -R 10000:10000 /vernemq && \
  ln -s /vernemq/etc /etc/vernemq && \
  ln -s /vernemq/data /var/lib/vernemq && \
  ln -s /vernemq/log /var/log/vernemq

# Ports
# 1883  MQTT
# 8883  MQTT/SSL
# 8080  MQTT WebSockets
# 44053 VerneMQ Message Distribution
# 4369  EPMD - Erlang Port Mapper Daemon
# 8888  Prometheus Metrics
# 9100 9101 9102 9103 9104 9105 9106 9107 9108 9109  Specific Distributed Erlang Port Range

EXPOSE 1883 8883 8080 44053 4369 8888 \
    9100 9101 9102 9103 9104 9105 9106 9107 9108 9109

VOLUME ["/vernemq/log", "/vernemq/data", "/vernemq/etc"]
HEALTHCHECK CMD vernemq ping | grep -q pong
USER vernemq
CMD ["start_vernemq"]
