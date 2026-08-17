FROM debian:trixie-slim@sha256:3a39a0592364683e6bab97937b72cad5a8fa6dcbbee90edb3bb48c7f8e94f258

ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C
ENV TZ=UTC

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        gcc-aarch64-linux-gnu \
        bison \
        flex \
        bc \
        python3 \
        python3-dev \
        python3-setuptools \
        python3-pkg-resources \
        python3-pyelftools \
        swig \
        openssl \
        libssl-dev \
        libgnutls28-dev \
        git \
        ca-certificates \
        wget \
        xxd \
        device-tree-compiler \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/radxa-zero3-boot-firmware
ENV MAKEFLAGS="-j$(nproc)"
ENV BUILD_DIR=/build
ENV OUT_DIR=/out
RUN mkdir -p /build /out

COPY pins/ /opt/radxa-zero3-boot-firmware/pins/
COPY scripts/build/ /opt/radxa-zero3-boot-firmware/scripts/build/
RUN chmod +x /opt/radxa-zero3-boot-firmware/scripts/build/*.sh

ENTRYPOINT ["/opt/radxa-zero3-boot-firmware/scripts/build/all.sh"]