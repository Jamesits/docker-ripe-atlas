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

The following prebuilt tags are available at [Docker Hub](https://hub.docker.com/r/jamesits/ripe-atlas). The `latest` tag supports [multi-arch](https://www.docker.com/blog/multi-arch-build-and-images-the-simple-way/), and should be used by default.

* **`latest`: For all supported devices listed below (multi-arch)**
* `latest-arm64`: For arm64 (aarch64) devices
* `latest-armel`: For armv6l (armel) devices
* `latest-armv7l`: For armv7l (armhf) devices
* `latest-i386`: For i386 devices
* `latest-amd64`: For amd64 devices

## Running

### Using `docker run`

First we start the container:

```shell
docker run --detach --restart=always \
	--log-driver json-file --log-opt max-size=10m \
	--cpus=1 --memory=64m --memory-reservation=64m \
	--cap-drop=ALL --cap-add=CHOWN --cap-add=SETUID --cap-add=SETGID --cap-add=DAC_OVERRIDE --cap-add=NET_RAW \
	-v /var/atlas-probe/etc:/var/atlas-probe/etc \
	-v /var/atlas-probe/status:/var/atlas-probe/status \
	-e RXTXRPT=yes \
	--name ripe-atlas --hostname "$(hostname --fqdn)" \
	jamesits/ripe-atlas:latest
```

### Using Docker Compose

An example [`docker-compose.yaml`](/docker-compose.yaml) is provided. 

```shell
git clone https://github.com/Jamesits/docker-ripe-atlas.git
cd docker-ripe-atlas
docker-compose pull
docker-compose up -d
```

## Registering the Probe

Fetch the generated public key:

```shell
cat /var/atlas-probe/etc/probe_key.pub
```

[Register](https://atlas.ripe.net/apply/swprobe/) the probe with your public key. After the registration being manually processed, you'll see your new probe in your account.

## Building

If you don't want to use the prebuilt image hosted on the Docker Hub, you can build your own image.

```shell
DOCKER_BUILDKIT=1 docker build -t ripe-atlas .
```

Note that building this container image requires [BuildKit](https://docs.docker.com/develop/develop-images/build_enhancements/).

## Caveats

### IPv6

Docker does not enable IPv6 by default. If you want IPv6 support, some level of setup and a basic understanding of IPv6 is required. Swarm mode & some Kubernetes implementation supports IPv6 too with extra configuration.

#### Using native address assignment

If you happened to have a block of static IPv6 addresses routed to your host, you can directly assign one of the addresses to the container. Edit `/etc/docker/daemon.json` and add native IPv6 address blocks, then restart the Docker daemon. An example:

```json
{
  "ipv6": true,
  "fixed-cidr-v6": "2001:db8:a1a3::/48"
}
```

Notes:
- These config work on Docker for Linux only
- If `daemon.json` exists, merge the config lines instead of directly overwriting it; if it doesn't exist, create it manually
- For more info, see [the official doc](https://docs.docker.com/config/daemon/ipv6/)

#### Using NAT (NPTv6)

If your ISP does not conform to [BCOP 690](https://www.ripe.net/publications/docs/ripe-690) (very common), and/or your router cannot route smaller blocks of IPv6 to one server even if it has been assigned a block of valid IPv6 addresses (also very common), the method above might not work for you. As a workaround, you can setup NAT with either [Docker's builtin experimental IPv6 NAT support](https://blog.iphoting.com/blog/2021/02/10/ipv6-docker-docker-compose-and-shorewall6-ip6tables/), `robbertkl/docker-ipv6nat` or similar projects. Manual iptables/nftables NAT setup is also possible, but *hanc marginis exiguitas non caperet*. 

Firstly, edit kernel parameters to enable IPv6 routing. 

```shell
cat > /etc/sysctl.d/50-docker-ipv6.conf <<EOF
net.ipv6.conf.eth0.accept_ra=2
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.default.forwarding=1
EOF
sysctl -p /etc/sysctl.d/50-docker-ipv6.conf
```

Notes:
- This potentially introduces more attack surface and might require you set up IPv6 firewall rules to make yourself safe
- This might break your network and your mileage may vary
- Swap `eth0` with your primary network adapter name
- If you use static IPv6 assignment instead of SLAAC, change `accept_ra` to `0`

Secondly, create a IPv6 NAT enabled network.

```shell
docker network create --ipv6 --subnet=fd00:a1a3::/48 ripe-atlas-network
docker run -d --restart=always -v /var/run/docker.sock:/var/run/docker.sock:ro -v /lib/modules:/lib/modules:ro --cap-drop=ALL --cap-add=NET_RAW --cap-add=NET_ADMIN --cap-add=SYS_MODULE --net=host --name=ipv6nat robbertkl/ipv6nat:latest
```

Finally, start the RIPE Atlas container with argument `--net=ripe-atlas-network`. 

### Auto Update

Use this recipe for auto updating the docker container.

```shell
docker run --detach --restart=always -v /var/run/docker.sock:/var/run/docker.sock --name watchtower containrrr/watchtower --cleanup --label-enable
```

Then start the RIPE Atlas container with argument `--label=com.centurylinklabs.watchtower.enable=true`.

### Backup

All the config files are stored at `/var/atlas-probe`. Just backup it.
