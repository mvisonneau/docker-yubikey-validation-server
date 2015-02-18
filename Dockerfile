# yubikey-validation-server
# Author : Maxime VISONNEAU - @mvisonneau
#
# VERSION 0.1
# 
# Prereq :  rng-tools - rngd -r /dev/urandom
# BUILD : 	docker build -t <username>/yubiserver .
# RUN :		docker run -d -p 8000:80 <yourname>/yubiserver -name yubikey-server
# 	

FROM ubuntu:14.04
MAINTAINER Maxime VISONNEAU <maxime.visonneau@gmail.com>

# Installation & Configuration

RUN DEBIAN_FRONTEND=noninteractive
RUN apt-get update
RUN apt-get install -y --force-yes debconf software-properties-common supervisor
RUN mkdir -p /root /var/lock/apache2 /var/run/apache2 /var/log/supervisor
ADD ./conf/ /root/
ADD ./conf/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN debconf-set-selections /root/yubi.seed
RUN add-apt-repository ppa:yubico/stable
RUN apt-get update
RUN echo 'exit 0' > /usr/sbin/policy-rc.d 
RUN apt-get install -y --force-yes yubikey-ksm yubikey-val
RUN gpg --no-tty --batch --trust-model always --gen-key /root/gpg.conf
RUN gpg --no-tty --import default.sec
RUN ykksm-gen-keys --urandom 1 10 > /root/keys.txt
RUN gpg --no-tty --trust-model always -a -s --encrypt -r `gpg --no-tty --list-keys | head -n 3 | tail -1 | awk '{print $2}' | cut -d '/' -f2` < /root/keys.txt > /root/encrypted_keys.txt
RUN /etc/init.d/mysql start && ykksm-import --database 'DBI:mysql:dbname=ykksm;host=127.0.0.1' --db-user ykksmreader --db-passwd unsecured < /root/encrypted_keys.txt
RUN /etc/init.d/mysql start && \
	echo "######### KEYS ###########" && \
	echo "---" && \
	for i in `grep -v ^# /root/keys.txt`; do echo "key`echo $i | cut -d',' -f1`:"; echo "  public_id: `echo $i | cut -d',' -f2`"; echo "  private_id: `echo $i | cut -d',' -f3`";  echo "  secret_key: `echo $i | cut -d',' -f4`"; done; \
	rm -f /root/keys.txt && \
	echo "######## CLIENT ##########" && \
	echo "---\nclient:" && \
	echo "  id:  `ykval-export-clients | cut -d',' -f1`" && \
	echo "  key: `ykval-export-clients | cut -d',' -f4`"

# Expose and Startup
EXPOSE 80
CMD ["/usr/bin/supervisord"]