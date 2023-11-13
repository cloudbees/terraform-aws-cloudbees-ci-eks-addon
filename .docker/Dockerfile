# Copyright (c) CloudBees, Inc.

FROM ubuntu:22.04
SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND=noninteractive \
    DOCKERFILE_PATH=.docker \
    ASDF_VERSION=v0.11.3 \
    USER=root

#https://packages.ubuntu.com/
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends git \
    # No gpg, https://stackoverflow.com/a/61692849 
    unzip \
    gnupg \
    gpg-agent \
    parallel \ 
    vim \
    wget \
    less \
    ca-certificates \
    openssh-client \
    wget \
    curl \
    make \
    # https://brain2life.hashnode.dev/how-to-install-pyenv-python-version-manager-on-ubuntu-2004
    build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*


WORKDIR /${USER}

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
    #https://github.com/asdf-vm/asdf/issues/276#issuecomment-907063520
    cut -d' ' -f1 .tool-versions|xargs -i asdf plugin add {} && \
    asdf install

ENTRYPOINT ["/bin/bash"]