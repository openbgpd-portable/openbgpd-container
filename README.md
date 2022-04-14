# Container image for OpenBGPD

## About

Source files and build instructions for an [OCI](https://opencontainers.org/) image (compatible with e.g. Docker or Podman) for [OpenBGPD](https://www.openbgpd.org/). It's a free implementation of the Border Gateway Protocol (BGP), Version 4.

## Usage

The OCI image automatically starts OpenBGPD, if a valid configuration has been provided. Validated ROA Payloads (VRPs) from [rpki-client](https://www.rpki-client.org/) can be passed optionally, too. It may be started with Docker using:

```shell
docker run --name openbgpd \
           --volume /path/to/openbgpd/conf/bgpd.conf:/etc/bgpd/bgpd.conf \
           --volume /path/to/openbgpd/run:/run/bgpd \
           --volume /path/to/openbgpd/rpki-client:/var/lib/rpki-client \
           --detach openbgpd/openbgpd:latest
```

And it may be started with Podman using:

```shell
podman run --name openbgpd \
           --volume /path/to/openbgpd/conf/bgpd.conf:/etc/bgpd/bgpd.conf \
           --volume /path/to/openbgpd/run:/run/bgpd \
           --volume /path/to/openbgpd/rpki-client:/var/lib/rpki-client \
           --detach quay.io/openbgpd/openbgpd:latest
```

## Volumes

  * `/etc/bgpd/` - Directory for the OpenBGPD configuration file `bgpd.conf` that `bgpd` will load by default. An example can be [downloaded separately](https://github.com/openbgpd-portable/openbgpd-openbsd/blob/master/src/etc/examples/bgpd.conf).
  * `/run/bgpd/` - Directory that contains the Unix domain socket for remote control of OpenBGPD using `bgpctl` (which is also part of this OCI image).
  * `/var/lib/rpki-client/` - Directory using which Validated ROA Payloads (VRPs) from [rpki-client](https://www.rpki-client.org/) can be passed to OpenBGPD.

While none of the volumes is required, meaningful usage requires at least a proper `bgpd.conf` configuration file via `/etc/bgpd`.

## Environment Variables

  * `TZ` - Time zone according to IANA's time zone database, e.g. `Europe/Amsterdam`, defaults to `UTC`.

## Exposed Ports

  * `179` - TCP port for inbound BGP sessions.

## Custom images

For custom OCI images, the following build arguments can be passed:

  * `VERSION` - Version of the signed portability shim release tarball, defaults to `7.3`.
  * `PORTABLE_GIT` - Git repository URL of the portability shim, defaults to `https://github.com/openbgpd-portable/openbgpd-portable.git`.
  * `PORTABLE_COMMIT` - Git commit, branch or tag of the portability shim, e.g. `master`, unset by default.
  * `OPENBSD_GIT` - Git repository URL of the OpenBSD source code, defaults to `https://github.com/openbgpd-portable/openbgpd-openbsd.git`.
  * `OPENBSD_COMMIT` - Git commit, branch or tag of the OpenBSD source code, e.g. `master`, unset by default.

To build a custom OCI image from current Git, e.g. `--build-arg PORTABLE_COMMIT=master` needs to be passed.

## Pipeline / Workflow

[Docker Hub](https://hub.docker.com/) and [Quay](https://quay.io/) can both [automatically build](https://docs.docker.com/docker-hub/builds/) OCI images from a [linked GitHub account](https://docs.docker.com/docker-hub/builds/link-source/) and automatically push the built image to the respective container repository. However, as of writing, this leads to OCI images for only the `amd64` CPU architecture. To support as many CPU architectures as possible (currently `386`, `amd64`, `arm/v6`, `arm/v7`, `arm64/v8`, `ppc64le` and `s390x`), [GitHub Actions](https://github.com/features/actions) are used. There, the current standard workflow "[Build and push OCI image](.github/workflows/image.yml)" roughly uses first a [GitHub Action to install QEMU static binaries](https://github.com/docker/setup-qemu-action), then a [GitHub Action to set up Docker Buildx](https://github.com/docker/setup-buildx-action) and finally a [GitHub Action to build and push Docker images with Buildx](https://github.com/docker/build-push-action).

Thus the OCI images are effectively built within the GitHub infrastructure (using [free minutes](https://docs.github.com/en/github/setting-up-and-managing-billing-and-payments-on-github/about-billing-for-github-actions) for public repositories) and then only pushed to both container repositories, Docker Hub and Quay (which are also free for public repositories). This not only saves repeated CPU resources but also ensures identical bugs independent from which container repository the OCI image gets finally pulled (and somehow tries to keep it distant from program changes such as [Docker Hub Rate Limiting](https://www.docker.com/increase-rate-limits) in 2020). The authentication for the pushes to the container repositories happen using access tokens, which at Docker Hub need to be bound to a (community) user and at Quay using a robot account as part of the organization. These access tokens are saved as "repository secrets" as part of the settings of the GitHub project.

To avoid maintaining one `Dockerfile` per CPU architecture, the single one is automatically multi-arched using `sed -e 's/^\(FROM\) \(alpine:.*\)/ARG ARCH=\n\1 ${ARCH}\2/' -i Dockerfile` as part of the workflow itself. While this might feel hackish, it practically works very well.

For each release of the project, a new Git branch (named like the version of the release, e.g. `7.3`) is created (based on the default branch, e.g. `master`). The workflow takes care about creating and moving container tags, such as `latest`. By not using Git tags but branches, downstream bug fixes can be easily applied to the OCI image (e.g. for bugs in the `Dockerfile` or patches for the source code itself). Old branches are not touched anymore, equivalent to old release archives.

Each commit to a Git branch triggers the workflow and leads to OCI images being pushed (except for GitHub pull requests), where the container tag is always based on the Git branch name. OCI images with non-release container tags pushed for testing purposes need to be cleaned up manually at the container repositories. Additionally, a cron-like option in the workflow leads to a nightly build being also tagged as `nightly`.

[Re-running a workflow](https://docs.github.com/en/actions/managing-workflow-runs/re-running-a-workflow) for failed builds can be performed using the GitHub web interface at the "Actions" section. However, to re-run older or successful builds (e.g. to achieve a newer operating system base image layer for an existing release), `git commit --allow-empty -m "Reason" && git push` might do the trick (because the [GitHub Actions API](https://stackoverflow.com/questions/56435547/how-do-i-re-run-github-actions) doesn't seem to allow such re-runs either).

## License

This project is licensed under the ISC License - see the [LICENSE](LICENSE) file for details.

As with all OCI images, these also contain other software under other licenses (such as BusyBox etc. from the base distribution, along with any direct or indirect dependencies of the contained OpenBGPD).

As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.
