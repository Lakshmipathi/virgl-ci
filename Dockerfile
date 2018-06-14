FROM debian:unstable-slim

ENV DEBIAN_FRONTEND=noninteractive

# Wait for Debian to ship libwayland-egl
ENV KNOWN_GOOD_MESA=67f7a16b5985
ENV KNOWN_GOOD_CTS=fd68124a565e
ENV KNOWN_GOOD_EPOXY=737b6918703c

ENV GOPATH=/usr/local/go
ENV PATH=$PATH:/usr/local/go/bin
ENV LD_LIBRARY_PATH=/usr/local/lib64:/usr/local/lib
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:/usr/local/share/pkgconfig
ENV LDFLAGS="-L/usr/local/lib64"

ENV XDG_RUNTIME_DIR=/tmp
ENV WAYLAND_DISPLAY=wayland-0
ENV SDL_VIDEODRIVER=wayland

RUN echo 'path-exclude=/usr/share/doc/*' > /etc/dpkg/dpkg.cfg.d/99-exclude-cruft
RUN echo 'path-exclude=/usr/share/man/*' >> /etc/dpkg/dpkg.cfg.d/99-exclude-cruft
RUN echo '#!/bin/sh' > /usr/sbin/policy-rc.d
RUN echo 'exit 101' >> /usr/sbin/policy-rc.d
RUN chmod +x /usr/sbin/policy-rc.d

RUN echo deb-src http://deb.debian.org/debian unstable main >> /etc/apt/sources.list

RUN /usr/sbin/update-ccache-symlinks

RUN apt-get update && \
    apt-get -y install ca-certificates && \
    apt-get -y install --no-install-recommends \
      mercurial \
      libgbm-dev \
      libxvmc-dev \
      libsdl2-dev \
      autoconf \
      golang-go \
      cmake \
      spirv-headers \
      weston \
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
      kbd && \
    apt-get -y build-dep --no-install-recommends \
      qemu \
      mesa \
      virglrenderer \
      libepoxy \
      libsdl2 \
      piglit && \
    apt-get clean

# Drop this once http://hg.libsdl.org/SDL/rev/295cf9910d75 makes it into Debian
WORKDIR /tmp/SDL
RUN hg clone http://hg.libsdl.org/SDL . && \
    ./configure  --prefix=/usr/local \
                 --disable-rpath \
                 --enable-sdl-dlopen \
                 --disable-loadso \
                 --disable-nas \
                 --disable-esd \
                 --disable-arts \
                 --disable-alsa-shared \
                 --disable-pulseaudio-shared \
                 --enable-ibus \
                 --disable-x11-shared \
                 --disable-video-directfb \
                 --enable-video-opengles \
                 --enable-video-wayland \
                 --disable-wayland-shared \
                 --disable-video-vulkan && \
    make -j$(nproc) install && \
    rm -rf /tmp/SDL
WORKDIR /

ARG KNOWN_GOOD_EPOXY=737b6918703c
RUN date && df -h
WORKDIR /tmp/libepoxy
RUN git clone https://github.com/anholt/libepoxy.git . && \
    git checkout ${KNOWN_GOOD_EPOXY} && \
    git log --oneline -n 1 && \
    ./autogen.sh --prefix=/usr/local && \
    make -j$(nproc) install && \
    rm -rf /tmp/libepoxy
WORKDIR /

# Wait for Debian to ship libwayland-egl
ARG KNOWN_GOOD_MESA=67f7a16b5985
WORKDIR /tmp/mesa
RUN date && df -h
RUN git clone git://anongit.freedesktop.org/mesa/mesa . && \
    git checkout ${KNOWN_GOOD_MESA} && \
    git log --oneline -n 1 && \
    ./autogen.sh --prefix=/usr/local --with-platforms="drm x11 wayland" --with-dri-drivers="i965" --with-gallium-drivers="swrast virgl radeonsi" --enable-debug --enable-llvm ac_cv_path_LLVM_CONFIG=llvm-config-6.0 && \
    make -j$(nproc) install && \
    rm -rf /tmp/mesa
WORKDIR /

RUN go get -v github.com/tomeuv/fakemachine/cmd/fakemachine
RUN go install -x github.com/tomeuv/fakemachine/cmd/fakemachine
#COPY weston.service /usr/lib/systemd/system/.
COPY weston.service /tmp

