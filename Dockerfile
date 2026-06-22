# p4lang's Ubuntu packages for p4c/BMv2 are published for amd64.
# On Apple Silicon, build with: docker buildx build --platform linux/amd64 --load ...
FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    && source /etc/lsb-release \
    && echo "deb http://download.opensuse.org/repositories/home:/p4lang/xUbuntu_${DISTRIB_RELEASE}/ /" \
       > /etc/apt/sources.list.d/home:p4lang.list \
    && curl -fsSL "https://download.opensuse.org/repositories/home:/p4lang/xUbuntu_${DISTRIB_RELEASE}/Release.key" \
       | gpg --dearmor > /etc/apt/trusted.gpg.d/home_p4lang.gpg \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       bash \
       git \
       iproute2 \
       iputils-ping \
       make \
       mininet \
       net-tools \
       p4lang-bmv2 \
       p4lang-p4c \
       python3 \
       python3-pip \
       sudo \
       tcpdump \
       tshark \
       vim-tiny \
    && python3 -m pip install --no-cache-dir scapy \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY docker/entrypoint.sh /usr/local/bin/p4-hw-entrypoint
RUN chmod +x /usr/local/bin/p4-hw-entrypoint

ENTRYPOINT ["/usr/local/bin/p4-hw-entrypoint"]
CMD ["/bin/bash"]
