FROM ubuntu:latest

RUN apt-get -y update && \
    apt-get -y install xorriso sed curl gpg wget fdisk isolinux && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys && \
    apt-get -y autoremove && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir /root/.gnupg && \
    chmod 600 /root/.gnupg

WORKDIR /app

ENTRYPOINT [ "/bin/bash" ]