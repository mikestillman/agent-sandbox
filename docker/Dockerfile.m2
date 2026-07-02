FROM m2-agent-base

USER root

COPY docker/scripts/install-m2-packages.sh /tmp/
RUN bash /tmp/install-m2-packages.sh

USER developer
WORKDIR /work
