FROM node:slim as vs-builder

WORKDIR /root
RUN apt-get update -y -q \
  && apt-get install -y -q --no-install-recommends \
    ca-certificates \
    git
RUN npm install -g @vscode/vsce
RUN git clone https://github.com/ccyip/taype-vscode.git \
  && cd taype-vscode \
  && vsce package -o taype.vsix

FROM debian:stable

ENV LANG C.UTF-8

SHELL ["/bin/bash", "--login", "-o", "pipefail", "-c"]

# Install system dependencies
RUN apt-get update -y -q \
  && apt-get install -y -q --no-install-recommends \
    build-essential \
    git \
    curl \
    libffi-dev \
    libffi7 \
    libgmp-dev \
    libgmp10 \
    libntl-dev \
    libncurses-dev \
    libncurses5 \
    libtinfo5 \
    bubblewrap \
    ca-certificates \
    pkg-config \
    sudo \
    unzip \
    cmake \
    libssl-dev \
    vim \
    python3-virtualenv

# Install opam
RUN echo /usr/local/bin | \
    bash -c "sh <(curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)"

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

RUN rm -rf ~/.cache

# Create user
ARG guest=pr3cog
RUN useradd --no-log-init -ms /bin/bash -G sudo -p '' ${guest}

USER ${guest}
WORKDIR /home/${guest}

# Install code-server extensions and configuration
RUN mkdir -p .config/code-server \
  && cd .config/code-server \
  && echo 'bind-addr: 0.0.0.0:8080' >> config.yaml \
  && echo 'auth: none' >> config.yaml \
  && echo 'cert: false' >> config.yaml
RUN mkdir .local
COPY --from=vs-builder --chown=${guest}:${guest} /root/taype-vscode/taype.vsix .local
RUN code-server --install-extension haskell.haskell | grep 'was successfully installed'
RUN code-server --install-extension ocamllabs.ocaml-platform | grep 'was successfully installed'
RUN code-server --install-extension maximedenes.vscoq | grep 'was successfully installed'
RUN code-server --install-extension ms-python.python | grep 'was successfully installed'
RUN code-server --install-extension .local/taype.vsix | grep 'was successfully installed'

# Install the Haskell toolchain
ENV BOOTSTRAP_HASKELL_NONINTERACTIVE=1
ENV BOOTSTRAP_HASKELL_GHC_VERSION=9.4.5
ENV BOOTSTRAP_HASKELL_CABAL_VERSION=3.10.1.0
ENV BOOTSTRAP_HASKELL_INSTALL_NO_STACK=1
RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
RUN echo 'source "$HOME/.ghcup/env"' >> ~/.profile

# Install the OCaml toolchain
RUN opam init -a -y --bare --disable-sandboxing --dot-profile="~/.profile" \
  && opam switch create default --package="ocaml-variants.4.14.1+options,ocaml-option-flambda" \
  && eval $(opam env) \
  && opam update -y \
  && opam install -y dune ctypes sexplib containers

# Setup Python virtual environment
RUN virtualenv venv \
  && echo 'source "$HOME/venv/bin/activate"' >> ~/.profile

# Install Python dependencies
RUN pip install pyparsing==3.0.9 lark

# Build HElib
RUN git clone https://github.com/homenc/HElib.git \
  && cd HElib \
  && git checkout v2.2.2 \
  && mkdir build \
  && cd build \
  && cmake .. \
  && make -j$(nproc) \
  && sudo make install

# Build Coyote
RUN git clone https://github.com/raghav198/coyote.git \
  && cd coyote \
  && pip install --editable .

# Build taype-drivers
RUN git clone --recursive https://github.com/ccyip/taype-drivers.git \
  && cd taype-drivers \
  && (cd emp/ffi && sudo make install) \
  && dune build \
  && dune install
# Fix linker
RUN sudo /sbin/ldconfig

# Remove some cache to save space
RUN rm -rf ~/.ghcup/cache

ENV DUNE_BUILD_DIR=_build_docker
ENV COIL_DIR=/home/${guest}/controlled-leaking

# Port for code-server
EXPOSE 8080

CMD ["/bin/bash", "--login"]
