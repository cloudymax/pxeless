FROM ubuntu:latest

RUN apt-get -y update && \
    apt-get -y install squashfuse \
	squashfs-tools \
	xorriso \
	fakeroot \
	sed \
	curl \
	gpg \
	wget \
	fdisk \
	sudo \
	isolinux && \
	apt-key adv --keyserver keyserver.ubuntu.com --recv-keys && \
	apt-get -y autoremove && \
	apt-get -y clean && \
	rm -rf /var/lib/apt/lists/* && \
	mkdir /root/.gnupg && \
	chmod 600 /root/.gnupg

VOLUME /data
WORKDIR /data

COPY image-create.sh /data

ENTRYPOINT [ "/data/image-create.sh" ]
