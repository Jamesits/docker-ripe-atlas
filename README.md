# RIPE Atlas Docker Image

This is the [RIPE Atlas software probe](https://atlas.ripe.net/docs/software-probe/) packaged as a Docker image.

[![Build Status](https://dev.azure.com/nekomimiswitch/General/_apis/build/status/docker-ripe-atlas?branchName=master)](https://dev.azure.com/nekomimiswitch/General/_build/latest?definitionId=83&branchName=master)

## Requirements

* 1 CPU core (of course)
* 20MiB memory
* 100MiB HDD
* A Linux installation with Docker installed
* Internet access

## Tags

The following prebuilt tags are available at [Docker Hub](https://hub.docker.com/r/jamesits/ripe-atlas):

* `latest`: For arm64 (x86\_64) devices
* `latest-armv7l`: For armv7l (armhf) devices, e.g. Raspberry Pi (CI donated by [@OtakuNekoP](https://github.com/OtakuNekoP))

## Running

First we start the container:

```shell
docker run --detach --restart=always --log-opt max-size=10m \
	--cpus=1 --memory=64m --memory-reservation=64m \
	--cap-add=SYS_ADMIN --cap-add=NET_RAW --cap-add=CHOWN \
	-v /var/atlas-probe/etc:/var/atlas-probe/etc \
	-v /var/atlas-probe/status:/var/atlas-probe/status \
	-e RXTXRPT=yes \
	--name ripe-atlas --hostname "$(hostname --fqdn)" \
	jamesits/ripe-atlas:latest
```

Then we fetch the generated public key:

```shell
cat /var/atlas-probe/etc/probe_key.pub
```

[Register](https://atlas.ripe.net/apply/swprobe/) the probe with your public key. After the registration being manually processed, you'll see your new probe in your account.

## Caveats

### IPv6

Docker's IPv6 support is still [like shit](https://github.com/moby/moby/issues/25407). As a workaround, you can use IPv6 NAT like this:

```shell
cat > /etc/sysctl.d/50-docker-ipv6.conf <<EOF
net.ipv6.conf.eth0.accept_ra=2
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
EOF
sysctl -p /etc/sysctl.d/50-docker-ipv6.conf
docker network create --ipv6 --subnet=fd00:a1a3::/48 ripe-atlas-network
docker run -d --restart=always -v /var/run/docker.sock:/var/run/docker.sock:ro -v /lib/modules:/lib/modules:ro --cap-drop=ALL --cap-add=NET_RAW --cap-add=NET_ADMIN --cap-add=SYS_MODULE --net=host --name=ipv6nat robbertkl/ipv6nat:latest
```

Then start the RIPE Atlas container with argument `--net=ripe-atlas-network`. 

Note this might break your network and your mileage may vary. You should swap `eth0` with your primary network adapter name, and if you use static IPv6 assignment instead of SLAAC, change `accept_ra` to `0`.

### Auto Update

Use this recipe for auto updating the docker container.

```shell
docker run -d -v /var/run/docker.sock:/var/run/docker.sock --name watchtower containrrr/watchtower --cleanup --label-enable
```

Then start the RIPE Atlas container with argument `--label=com.centurylinklabs.watchtower.enable=true`.

### Backup

All the config files are stored at `/var/atlas-probe`. Just backup it.

