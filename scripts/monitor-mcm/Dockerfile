
FROM registry.access.redhat.com/ubi8/ubi-minimal:latest

LABEL name="sre-mcm-core-monitor" \
    vendor="IBM" \
    version="0.1.0" \
    release="2020.3.0"

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.16.8/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/bin && \
    mkdir -p /testcases

COPY scripts /scripts

ENTRYPOINT ["/scripts/monitor.sh"]
