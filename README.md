# RIPE Atlas Docker Image

This is the [RIPE Atlas software probe](https://atlas.ripe.net/docs/software-probe/) packaged as a Docker image.

[![Build Status](https://dev.azure.com/nekomimiswitch/General/_apis/build/status/docker-ripe-atlas?branchName=master)](https://dev.azure.com/nekomimiswitch/General/_build/latest?definitionId=83&branchName=master)

## Running

First we start the container:

```shell
docker run -d \
	--restart=always \
	--memory=256m \
	--cap-add=SYS_ADMIN --cap-add=CAP_NET_RAW --cap-add=CAP_CHOWN \
	--mount type=tmpfs,destination=/var/atlasdata \
	--mount type=bind,src=/var/atlas-probe/etc,dst=/var/atlas-probe/etc \
	--mount type=bind,src=/var/atlas-probe/status,dst=/var/atlas-probe/status \
	--name ripe-atlas \
	jamesits/ripe-atlas:nightly
```

Then we fetch the generated public key:

```shell
cat /var/atlas-probe/etc/probe_key.pub
```

[Register](https://atlas.ripe.net/apply/swprobe/) the probe with your public key.

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

### Auto Update

Use this recipe for auto updating the docker container.

```shell
docker run -d -v /var/run/docker.sock:/var/run/docker.sock --name watchtower containrrr/watchtower --cleanup --label-enable
```

Then start the RIPE Atlas container with argument `--label=com.centurylinklabs.watchtower.enable=true`.
