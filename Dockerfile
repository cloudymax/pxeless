# End of life 2024-01-20
FROM ubuntu:lunar

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

COPY image-create.sh /app/

VOLUME /data
WORKDIR /data

ENTRYPOINT [ "/app/image-create.sh" ]
