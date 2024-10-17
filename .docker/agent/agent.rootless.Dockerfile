# Copyright (c) CloudBees, Inc.

FROM alpine:3.19.0

ENV TF_VERSION=1.6.6 \
    KUBECTL_VERSION=1.29.0 \
    VELERO_VERSION=1.13.0 \
    USER=bp-agent \
    ARCH=amd64

RUN apk add --update --no-cache \
    bash \
    unzip \
    zip \
    curl \
    git \
    make \
    aws-cli \
    yq \
    jq

RUN curl -sLO https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_${ARCH}.zip && \
    unzip terraform_${TF_VERSION}_linux_${ARCH}.zip && \
    mv terraform /usr/bin/terraform && \
    rm terraform_${TF_VERSION}_linux_${ARCH}.zip

RUN curl -sLO https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl && \
    mv kubectl /usr/bin/kubectl && \
    chmod +x /usr/bin/kubectl

RUN curl -sLO https://github.com/vmware-tanzu/velero/releases/download/v${VELERO_VERSION}/velero-v${VELERO_VERSION}-linux-${ARCH}.tar.gz && \
    tar zxvf velero-v${VELERO_VERSION}-linux-${ARCH}.tar.gz && \
    mv velero-v${VELERO_VERSION}-linux-${ARCH}/velero /usr/bin/velero && \
    chmod +x /usr/bin/velero && \
    rm velero-v${VELERO_VERSION}-linux-${ARCH}.tar.gz

RUN adduser -s /bin/bash -h /${USER} -D ${USER}
WORKDIR /${USER}
USER ${USER}
