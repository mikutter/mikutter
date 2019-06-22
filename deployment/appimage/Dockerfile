FROM ubuntu:14.04

RUN apt-get update && apt-get install -y \
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
    libidn11-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY AppRun mikutter.desktop gen_appimage.sh /

ENV VOLUME /volume

ENTRYPOINT ["/gen_appimage.sh"]
