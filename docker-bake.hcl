# Set this if you use an internal Docker Hub mirror
variable "CR_DOCKER_HUB_PREFIX" {
    default = "docker.io"
}
variable "IMAGE_TAG_PREFIX" {
    default = "docker.io/jamesits/ripe-atlas"
}

group "default" {
    targets = ["artifacts", "ripe-atlas-probe", "ripe-atlas-anchor"]
}

target "_default" {
    dockerfile = "Dockerfile"
    platforms = ["linux/386", "linux/amd64", "linux/arm/v7", "linux/arm64"]
    args = {
        BUILDKIT_SYNTAX = "${CR_DOCKER_HUB_PREFIX}/docker/dockerfile:1"
    }
    annotations = [
        "index,manifest:org.opencontainers.image.authors=dockerhub@public.swineson.me",
        "index,manifest:org.opencontainers.image.source=https://github.com/jamesits/docker-ripe-atlas",
    ]
    attest = [
        "type=provenance,mode=max",
        "type=sbom,generator=${CR_DOCKER_HUB_PREFIX}/docker/buildkit-syft-scanner",
    ]
}

# For exporting the `*.deb` files
target "artifacts" {
    inherits = ["_default"]
    target = "artifacts"
    outputs = [
        { type = "local", dest = "out/", },
    ]
}

target "_ripe-atlas-probe" {
    target = "ripe-atlas-probe"
    annotations = [
        "index,manifest:org.opencontainers.image.title=ripe-atlas-probe",
    ]
    tags = [
        "${IMAGE_TAG_PREFIX}:latest",
        "${IMAGE_TAG_PREFIX}:latest-probe",
    ]
}

# To be overriden by the CI pipeline
target "ripe-atlas-probe" {
    inherits = ["_default", "_ripe-atlas-probe"]
}

target "_ripe-atlas-anchor" {
    target = "ripe-atlas-anchor"
    annotations = [
        "index,manifest:org.opencontainers.image.title=ripe-atlas-anchor",
    ]
    tags = [
        "${IMAGE_TAG_PREFIX}:latest-anchor",
    ]
}

# To be overriden by the CI pipeline
target "ripe-atlas-anchor" {
    inherits = ["_default", "_ripe-atlas-anchor"]
}
