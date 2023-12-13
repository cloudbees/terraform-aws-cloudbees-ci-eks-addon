# Copyright (c) CloudBees, Inc.

FROM debian:bookworm-slim
SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    ASDF_VERSION=v0.11.3 \
    USER=asdf \
    DOCKERFILE_PATH=blueprints

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    git \
    unzip \
    gnupg \
    gpg-agent \
    parallel \
    vim \
    wget \
    less \
    ca-certificates \
    openssh-client \
    curl \
    make && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN adduser --shell /bin/bash --home /${USER} --disabled-password ${USER}

WORKDIR /${USER}
USER ${USER}

COPY ${DOCKERFILE_PATH}/.tool-versions .tool-versions

RUN echo "source .bash_profile" >> .bashrc && \
    cat <<EOF >> .bash_profile
#ASDF Configuration
PATH=/${USER}/.asdf/shims:/home/$USER/.asdf/bin:${PATH}
source /${USER}/.asdf/asdf.sh
# https://github.com/asdf-vm/asdf/issues/1115#issuecomment-995026427
rm -rf .asdf/shims/* && asdf reshim
EOF

RUN git clone --depth 1 https://github.com/asdf-vm/asdf.git --branch ${ASDF_VERSION} .asdf && \
    source .asdf/asdf.sh && \
    cut -d' ' -f1 .tool-versions|xargs -i asdf plugin add {} && \
    asdf install

ENTRYPOINT ["/bin/bash"]
