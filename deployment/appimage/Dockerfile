FROM ubuntu:16.04

ARG ruby_version=2.6.3
ARG APPDIR=/AppDir

RUN apt update && apt install -y \
    git \
    wget \
    build-essential \
    libssl-dev \
    libreadline6-dev \
    libgdbm3 \
    libgdbm-dev \
    zlib1g-dev \
    libglib2.0-dev \
    libatk1.0-dev \
    libcairo2-dev \
    libgirepository1.0-dev \
    libgdk-pixbuf2.0-dev \
    libpango1.0-dev \
    libgtk2.0-dev \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://github.com/jemalloc/jemalloc/releases/download/5.2.0/jemalloc-5.2.0.tar.bz2 && \
        tar -xf jemalloc-5.2.0.tar.bz2 && \
        cd /jemalloc-5.2.0 && \
        ./configure --prefix=/usr && \
        make -j8 && \
        make install && \
        make "DESTDIR=$APPDIR" install

RUN wget -q https://cache.ruby-lang.org/pub/ruby/2.6/ruby-$ruby_version.tar.gz && \
        tar xf ruby-$ruby_version.tar.gz && \
        cd ruby-$ruby_version && \
        ./configure --enable-load-relative --with-jemalloc --prefix=/usr --disable-install-doc && \
        make -j8 && \
        make "DESTDIR=$APPDIR" install && \
        cp -v BSDL COPYING* GPL LEGAL README* $APPDIR/usr/lib/ruby

# use exec.so to run commands placed outside of the AppImage
# see https://github.com/darealshinji/AppImageKit-checkrt/pull/11
RUN mkdir $APPDIR/usr/optional \
    && wget -q -O $APPDIR/usr/optional/exec.so https://github.com/mikutter/execso/releases/download/2019-08-20/exec-x86_64-gnu-linux.so

COPY AppRun mikutter.desktop gen_appimage.sh /

ENV VOLUME /volume

ENTRYPOINT ["/gen_appimage.sh"]
