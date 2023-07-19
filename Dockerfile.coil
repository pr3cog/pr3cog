FROM debian:stable

ENV LANG C.UTF-8

SHELL ["/bin/bash", "--login", "-o", "pipefail", "-c"]

WORKDIR /root

# Install system dependencies
RUN apt-get update -y -q \
  && apt-get install -y -q --no-install-recommends \
    build-essential \
    git \
    libgmp-dev \
    libntl-dev \
    cmake \
    vim \
    python3-virtualenv

# Setup Python virtual environment
RUN virtualenv venv \
  && echo 'source "$HOME/venv/bin/activate"' >> ~/.bashrc

# Install Python dependencies
RUN pip install pyparsing==3.0.9 \
  && pip install lark

# Build HElib
RUN git clone https://github.com/homenc/HElib.git \
  && cd HElib \
  && git checkout v2.2.2 \
  && mkdir build \
  && cd build \
  && cmake .. \
  && make -j$(nproc) \
  && make install

# Build Coyote
RUN git clone https://github.com/raghav198/coyote.git \
  && cd coyote \
  && pip install --editable .
