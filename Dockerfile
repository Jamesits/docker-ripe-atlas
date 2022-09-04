## builder
FROM --platform=$BUILDPLATFORM debian:10-slim as builder
LABEL image="ripe-atlas-builder"
ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG DEBIAN_FRONTEND=noninteractive
ARG GIT_URL=https://github.com/RIPE-NCC/ripe-atlas-software-probe.git

WORKDIR /root

RUN if [ "$BUILDPLATFORM" != "$TARGETPLATFORM" ] ; then \
		case ${TARGETPLATFORM} in \
			"linux/arm64")	echo 'export CROSSBUILD_ARCH=arm64 CROSS_COMPILE_TARGET=aarch64-linux-gnu' > env ;; \
			"linux/arm/v7")	echo 'export CROSSBUILD_ARCH=armhf CROSS_COMPILE_TARGET=arm-linux-gnueabihf' > env ;; \
			"linux/386")	echo 'export CROSSBUILD_ARCH=i386 CROSS_COMPILE_TARGET=i686-linux-gnu' > env ;; \
			"linux/amd64")	echo 'export CROSSBUILD_ARCH=amd64 CROSS_COMPILE_TARGET=x86_64-linux-gnu' > env ;; \
			*) echo "Unsupported platform"; exit 1 ;; \
		esac \
		&& . ./env \
		&& dpkg --add-architecture $CROSSBUILD_ARCH \
		&& apt-get update -y \
		&& apt-get install -y libssl-dev:$CROSSBUILD_ARCH crossbuild-essential-$CROSSBUILD_ARCH; \
	fi \
	&& apt-get update -y \
	&& apt-get install -y git tar fakeroot libssl-dev libcap2-bin autoconf automake libtool build-essential

RUN git clone --recursive "$GIT_URL"

RUN if [ "$BUILDPLATFORM" != "$TARGETPLATFORM" ] ; then \
		. ./env \
		&& export CROSS_COMPILE="$CROSS_COMPILE_TARGET-" \
		&& sed -i 's/.\/configure/.\/configure --host='$CROSS_COMPILE_TARGET'/g' ./ripe-atlas-software-probe/build-config/debian/bin/make-deb \
		&& sed -i 's/ARCH=$(get_arch)/ARCH='$CROSSBUILD_ARCH'/g' ./ripe-atlas-software-probe/build-config/debian/bin/make-deb; \
	fi \
	&& ./ripe-atlas-software-probe/build-config/debian/bin/make-deb

## artifacts
FROM scratch AS artifacts
LABEL image="ripe-atlas-artifacts"

COPY --from=builder /root/atlasswprobe-*.deb /

## the actual image
FROM debian:stable-slim
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
