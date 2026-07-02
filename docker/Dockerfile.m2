FROM m2-agent-base

USER root

COPY docker/scripts/install-m2-packages.sh /tmp/
RUN bash /tmp/install-m2-packages.sh

# Inherits ENTRYPOINT (firewall + privilege drop) from the base image. Stays as
# root so the entrypoint can configure iptables; it execs as `developer`.
WORKDIR /workspace
