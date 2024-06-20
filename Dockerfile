FROM node:slim as vs-builder

WORKDIR /root
RUN apt-get update -y -q \
  && apt-get install -y -q --no-install-recommends \
    ca-certificates \
    git
RUN npm install -g @vscode/vsce
RUN git clone https://github.com/ccyip/taype-vscode.git \
  && cd taype-vscode \
  && git checkout 4a3c7b1187c8b2f2e5208235e3039f80cace2947 \
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
    libffi8 \
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
RUN mkdir -p .config/code-server
COPY --chown=${guest}:${guest} <<EOT .config/code-server/config.yaml
bind-addr: 0.0.0.0:8080
auth: none
cert: false
EOT
RUN mkdir .local
COPY --from=vs-builder --chown=${guest}:${guest} /root/taype-vscode/taype.vsix .local
RUN code-server --install-extension haskell.haskell | grep 'was successfully installed'
RUN code-server --install-extension ocamllabs.ocaml-platform | grep 'was successfully installed'
RUN code-server --install-extension ms-python.python | grep 'was successfully installed'
RUN code-server --install-extension .local/taype.vsix | grep 'was successfully installed'

# Setup shell environment
COPY --chown=${guest}:${guest} <<EOT .setup
if [ -z "\$SETUP_PR3COG_DONE" ]; then
  export SETUP_PR3COG_DONE=1
else
  return
fi

EOT
RUN echo 'source "$HOME/.setup"' >> ~/.profile
RUN echo 'source "$HOME/.setup"' >> ~/.bashrc

# Install the Haskell toolchain
ENV BOOTSTRAP_HASKELL_NONINTERACTIVE=1
ENV BOOTSTRAP_HASKELL_GHC_VERSION=9.4.7
ENV BOOTSTRAP_HASKELL_CABAL_VERSION=3.10.2.0
ENV BOOTSTRAP_HASKELL_INSTALL_NO_STACK=1
RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
RUN echo '[ -f "$HOME/.ghcup/env" ] && source "$HOME/.ghcup/env"' >> ~/.setup

# Install the OCaml toolchain
RUN opam init -a -y --bare --disable-sandboxing --dot-profile="~/.setup" \
  && opam switch create default --package="ocaml-variants.4.14.1+options,ocaml-option-flambda" \
  && eval $(opam env) \
  && opam update -y \
  && opam install -y dune ctypes containers containers-data \
    sexplib yojson ppx_deriving z3

# Setup Python virtual environment
RUN virtualenv venv \
  && echo 'source "$HOME/venv/bin/activate"' >> ~/.setup

# Build HElib
RUN git clone https://github.com/homenc/HElib.git \
  && cd HElib \
  && git checkout v2.3.0 \
  && mkdir build \
  && cd build \
  && cmake .. \
  && make -j$(nproc) \
  && sudo make install

# Build taype-drivers
RUN git clone https://github.com/ccyip/taype-drivers.git \
  && cd taype-drivers \
  && git checkout 5a748db3bf58df0dc977f288cb6ff21ce19578af \
  && git submodule update --init --recursive \
  && (cd emp/ffi && sudo make install) \
  && dune build \
  && dune install
# Fix linker
RUN sudo /sbin/ldconfig

# Build taype-driver-coil
RUN git clone https://github.com/ccyip/taype-driver-coil.git \
  && cd taype-driver-coil \
  && git checkout 5c54158537d7bc0a73eaf4395950e7c38f807c74 \
  && dune build \
  && dune install
  
# Build taype
RUN git clone https://github.com/ccyip/taype.git \
  && cd taype \
  && git checkout 33735b1ed5a7311647d67a50116cb5a0ea5d1465 \
  && (cd solver && dune build) \
  && cabal update \
  && cabal build \
  && cabal run shake

# Install Python dependencies
RUN pip install pyparsing==3.0.9 lark typing_extensions numpy networkx z3-solver
  
# Download coil
RUN git clone -b taype https://github.com/raghav198/controlled-leaking.git \
  && cd controlled-leaking \
  && git checkout 873a3f09f024456c5bfe533150198b0a5bc1f232 \
  && git submodule update --init --recursive \
  && echo 'export COIL_DIR="$HOME/controlled-leaking"' >> ~/.setup

# Remove some cache to save space
RUN rm -rf ~/.ghcup/cache

# Port for code-server
EXPOSE 8080

CMD ["/bin/bash", "--login"]
