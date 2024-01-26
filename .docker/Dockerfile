# Copyright (c) CloudBees, Inc.

FROM alpine:3.19.0

ENV ASDF_VERSION=v0.11.3 \
    USER=bp-agent \
    DOCKERFILE_PATH=.docker

RUN apk add --virtual .asdf-deps --no-cache bash \
    curl \
    git \
    make \
    aws-cli

SHELL ["/bin/bash", "-l", "-c"]

RUN adduser -s /bin/bash -h /${USER} -D ${USER}
WORKDIR /${USER}
USER ${USER}

COPY ${DOCKERFILE_PATH}/.tool-versions .tool-versions
COPY ${DOCKERFILE_PATH}/.bash_profile .bash_profile 
RUN echo "source .bash_profile" >> .bashrc
RUN git clone --depth 1 https://github.com/asdf-vm/asdf.git --branch ${ASDF_VERSION} .asdf && \
    source .asdf/asdf.sh && \
    cut -d' ' -f1 .tool-versions|xargs -i asdf plugin add {} && \
    asdf install

CMD ["/bin/bash"]
