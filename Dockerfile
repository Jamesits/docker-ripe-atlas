## builder
FROM --platform=$BUILDPLATFORM debian:11-slim AS builder
LABEL image="ripe-atlas-builder"
ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG DEBIAN_FRONTEND=noninteractive
ARG GIT_URL=https://github.com/RIPE-NCC/ripe-atlas-software-probe.git

WORKDIR /root

RUN if [ "$BUILDPLATFORM" != "$TARGETPLATFORM" ] ; then \
		case ${TARGETPLATFORM} in \
			"linux/arm64")	echo 'export CROSSBUILD_ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-' > env ;; \
			"linux/arm/v7")	echo 'export CROSSBUILD_ARCH=armhf CROSS_COMPILE=arm-linux-gnueabihf-' > env ;; \
			"linux/386")	echo 'export CROSSBUILD_ARCH=i386 CROSS_COMPILE=i686-linux-gnu-' > env ;; \
			"linux/amd64")	echo 'export CROSSBUILD_ARCH=amd64 CROSS_COMPILE=x86_64-linux-gnu-' > env ;; \
			*) echo "Unsupported platform"; exit 1 ;; \
		esac \
		&& . ./env \
		&& dpkg --add-architecture $CROSSBUILD_ARCH \
		&& apt update -y \
		&& apt install -y libssl-dev:$CROSSBUILD_ARCH crossbuild-essential-$CROSSBUILD_ARCH; \
	fi \
	&& apt update -y \
	&& apt install -y git build-essential debhelper libssl-dev

RUN git clone --recursive "$GIT_URL"

# Revert to 5080, 5090 needs further testing
WORKDIR /root/ripe-atlas-software-probe
RUN git checkout 67b0736887d33d1c42557e7c7694cbd4e5d8e6ee .
RUN git submodule update

# Temporary workaround for Debian libssl1.1 dependency issue
RUN sed -i 's/libssl1,/libssl1.1,/g' ./debian/control

RUN if [ "$BUILDPLATFORM" != "$TARGETPLATFORM" ] ; then \
		. ../env; \
	fi \
	&& dpkg-buildpackage -b -us -uc --host-arch=$CROSSBUILD_ARCH

## artifacts
FROM scratch AS artifacts
LABEL image="ripe-atlas-artifacts"

COPY --from=builder /root/ripe-atlas-common*.deb /root/ripe-atlas-probe*.deb /

## the actual image
FROM debian:11-slim
LABEL org.opencontainers.image.authors="dockerhub@public.swineson.me"
LABEL org.opencontainers.image.title="ripe-atlas"
ARG DEBIAN_FRONTEND=noninteractive

COPY --from=builder /root/ripe-atlas-common*.deb /root/ripe-atlas-probe*.deb /tmp/

ARG ATLAS_UID=101
ARG ATLAS_MEAS_UID=102
ARG ATLAS_GID=999
RUN ln -s /bin/true /bin/systemctl \
	&& adduser --system --uid $ATLAS_UID ripe-atlas \
	&& adduser --system --uid $ATLAS_MEAS_UID ripe-atlas-measurement \
	&& groupadd --force --system --gid $ATLAS_GID ripe-atlas \
	&& usermod -aG ripe-atlas ripe-atlas \
	&& usermod -aG ripe-atlas ripe-atlas-measurement \
	&& apt-get update -y \
	&& apt-get install -y libcap2-bin iproute2 openssh-client procps net-tools tini \
	&& dpkg -i /tmp/ripe-atlas*.deb \
	&& apt-get install -fy \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -f /tmp/ripe-atlas*.deb

COPY entrypoint.sh /usr/local/bin
RUN chmod +x /usr/local/bin/*

WORKDIR /etc/ripe-atlas
VOLUME [ "/etc/ripe-atlas", "/run/ripe-atlas/status" ]

ENTRYPOINT [ "tini", "--", "entrypoint.sh" ]
CMD [ "ripe-atlas" ]
