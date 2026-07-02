FROM m2-agent-base

USER root

COPY docker/scripts/install-m2-packages.sh /tmp/
RUN bash /tmp/install-m2-packages.sh

# Install the latest stable prebuilt M2 (PPA) + Emacs integration, alongside the
# from-source build. PPA is only reached at build time (firewall is off then).
COPY docker/scripts/install-m2-prebuilt.sh /tmp/
RUN bash /tmp/install-m2-prebuilt.sh

# Inherits ENTRYPOINT (firewall + privilege drop) from the base image. Stays as
# root so the entrypoint can configure iptables; it execs as `developer`.
WORKDIR /workspace
