## builder
FROM debian:10-slim as builder
LABEL image="ripe-atlas-builder"
ARG DEBIAN_FRONTEND=noninteractive
ARG GIT_URL=https://github.com/RIPE-NCC/ripe-atlas-software-probe.git

RUN apt-get update -y \
	&& apt-get install -y git tar fakeroot libssl-dev libcap2-bin autoconf automake libtool build-essential python

WORKDIR /root

RUN git clone --recursive "$GIT_URL"
RUN ./ripe-atlas-software-probe/build-config/debian/bin/make-deb

## the actual image
FROM debian:10-slim
LABEL maintainer="dockerhub@public.swineson.me"
LABEL image="ripe-atlas"
ARG DEBIAN_FRONTEND=noninteractive

COPY --from=builder /root/atlasswprobe-*.deb /tmp

ARG ATLAS_UID=101
ARG ATLAS_GID=999
RUN ln -s /bin/true /bin/systemctl \
	&& adduser --system --uid $ATLAS_UID atlas \
	&& groupadd --force --system --gid $ATLAS_GID atlas \
	&& usermod -aG atlas atlas \
	&& apt-get update -y \
	&& apt-get install -y libcap2-bin iproute2 openssh-client procps net-tools gosu \
	&& dpkg -i /tmp/atlasswprobe-*.deb \
	&& apt-get install -fy \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -f /tmp/atlasswprobe-*.deb \
	&& ln -s /usr/local/atlas/bin/ATLAS /usr/local/bin/atlas

COPY entrypoint.sh /usr/local/bin
RUN chmod +x /usr/local/bin/* \
	&& chown -R atlas:atlas /var/atlas-probe \
	&& mkdir -p /var/atlasdata \
	&& chown -R atlas:atlas /var/atlasdata \
	&& chmod 777 /var/atlasdata

WORKDIR /var/atlas-probe
VOLUME [ "/var/atlas-probe/etc", "/var/atlas-probe/status" ]

ENTRYPOINT [ "entrypoint.sh" ]
CMD [ "atlas" ]

