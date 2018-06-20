FROM debian:unstable-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV GOPATH=/usr/local/go
ENV PATH=$PATH:/usr/local/go/bin
ENV LD_LIBRARY_PATH=/usr/local/lib64:/usr/local/lib
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:/usr/local/share/pkgconfig
ENV LDFLAGS="-L/usr/local/lib64"

RUN echo 'path-exclude=/usr/share/doc/*' > /etc/dpkg/dpkg.cfg.d/99-exclude-cruft
RUN echo 'path-exclude=/usr/share/man/*' >> /etc/dpkg/dpkg.cfg.d/99-exclude-cruft
RUN echo '#!/bin/sh' > /usr/sbin/policy-rc.d
RUN echo 'exit 101' >> /usr/sbin/policy-rc.d
RUN chmod +x /usr/sbin/policy-rc.d

RUN echo deb-src http://deb.debian.org/debian unstable main >> /etc/apt/sources.list
RUN apt-get update && \
    apt-get -y install ca-certificates && \
    apt-get -y install --no-install-recommends \
      libgbm-dev \
      libxvmc-dev \
      autoconf \
      golang-go \
      cmake \
      spirv-headers \
      xinit \
      check \
      linux-image-amd64 \
      git \
      procps \
      systemd \
      dbus \
      strace \
      systemd-coredump \
      time \
      busybox \
      kbd \
      ccache \
      xserver-xorg-core \
      xterm && \
    apt-get -y build-dep --no-install-recommends \
      qemu \
      mesa \
      virglrenderer \
      libepoxy \
      piglit && \
    apt-get clean

RUN go get -v github.com/tomeuv/fakemachine/cmd/fakemachine
RUN go install -x github.com/tomeuv/fakemachine/cmd/fakemachine

ARG KNOWN_GOOD_EPOXY=737b6918703c
WORKDIR /libepoxy
RUN git clone https://github.com/anholt/libepoxy.git . && \
    git checkout ${KNOWN_GOOD_EPOXY} && \
    git log --oneline -n 1 && \
    ./autogen.sh --prefix=/usr/local && \
    make -j$(nproc) install && \
    rm -rf /libepoxy
WORKDIR /

ARG KNOWN_GOOD_CTS=fd68124a565e
WORKDIR /VK-GL-CTS
RUN git clone https://github.com/KhronosGroup/VK-GL-CTS.git . && \
    git checkout ${KNOWN_GOOD_CTS} && \
    git log --oneline -n 1 && \
    mkdir build && \
    cd build && \
    cmake .. -DDEQP_TARGET=x11_egl && \
    make -j$(nproc)  && find . -type f | xargs  strip  || true && \
    mv /VK-GL-CTS/build /usr/local/VK-GL-CTS && \
    rm -rf /VK-GL-CTS
WORKDIR /

ARG KNOWN_GOOD_PIGLIT=1a2f49f17fb45
WORKDIR /piglit
RUN git clone https://gitlab.freedesktop.org/mesa/piglit.git . && \
    git checkout ${KNOWN_GOOD_PIGLIT} && \
    git log --oneline -n 1 && \
    mkdir /usr/local/piglit  && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local/piglit . && \
    make -j$(nproc) install && rm -rf /piglit \
    find /usr/loca/piglit -type f | xargs  strip  || true 
WORKDIR /

ARG KNOWN_GOOD_MESA=8efdffba9408
WORKDIR /mesa
RUN git clone https://gitlab.collabora.com/tomeu/mesa.git . && \
    git checkout ${KNOWN_GOOD_MESA} && \
    git log --oneline -n 1 && \
    ./autogen.sh --prefix=/usr/local --with-platforms="drm x11 wayland" --with-dri-drivers="i965" --with-gallium-drivers="swrast virgl radeonsi r600" --enable-debug --enable-llvm ac_cv_path_LLVM_CONFIG=llvm-config-6.0 --enable-driglx-direct --enable-glx-tls --enable-texture-float && \
    make -j$(nproc) install && \
    rm -rf /mesa
WORKDIR /

