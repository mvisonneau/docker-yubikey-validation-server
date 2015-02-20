# docker-yubikey-validation-server
Dockerized stack of Yubico yubikey-ksm and yubikey-val

## Overview

This repository will help you build a working *Yubico(r) Yubikey Validation Server*. After digging around I did not see much of documentation about this. I don't know why Yubico is not so explicit about the existence of very useful packages onto their repository.

## Requirements

- docker

*Docker* is used in order to avoid the direct installation of all the KSM components onto your system.

- rng-tools

*rng-tools* generate entropy onto your machine making it able to automatically generate the gpg keys during the creation of the container.

## Usage

- Make sure you have **docker** and **rng-tools** installed and running
```bash
# Docker -- service docker start
pgrep docker
8765
987

# rng-tools -- rngd -r /dev/urandom
pgrep rngd
876
```

- Clone this repository

```bash
git clone https://github.com/mvisonneau/docker-yubikey-validation-server.git
```

- Adjust the **unsecured** fields into the `Dockerfile` and `conf/yubi.seed`

```bash
### Dockerfile
ENV DB_PASSWORD = unsecured

### conf/yubi.seed
mysql-server-5.5        mysql-server/root_password_again    password  unsecured
mysql-server-5.5        mysql-server/root_password          password  unsecured
yubikey-ksm             yubikey-ksm/mysql/admin-pass        password  unsecured
yubikey-ksm             yubikey-ksm/mysql/app-pass          password  unsecured
yubikey-val             yubikey-val/mysql/admin-pass        password  unsecured
yubikey-val             yubikey-val/mysql/app-pass          password  unsecured
```
- Adjust the amount of keys you want to generate into the `Dockerfile`

```bash
### Dockerfile
ENV KEYS_AMOUNT = 10
```

- Build the container and run it
```bash
cd docker-yubikey-validation-server
sudo docker build -t <username>/yubikey-server:0.1 .
sudo docker run --name yubikey-server -d -p 8000:80 <yourname>/yubikey-server:0.1
```

- Retreive your custom keys and client id, their supposed to be formatted as YAML

Those datas are very sensitive, you should keep them in at encrypted place where noone can access it.
They will be used in order to program your keys.

```yaml
######### KEYS ###########
---
key1:
  public_id: cccccccccccb
  private_id: fe9e85768b07
  secret_key: yu6765f3d1eafa89bee65aeb81b70888
key2:
  public_id: cccccccccccd
  private_id: 75o98a8907c6
  secret_key: 767u5434b4060516a833e121d32uy789

######## CLIENT ##########
---
client:
  id:  1
  key: gh8u5b0UIb989vatK3RwOpoLKJ=
```

- Test it

Check if the container is up and running :

```bash
sudo docker ps
CONTAINER ID        IMAGE                          COMMAND                CREATED             STATUS              PORTS                  NAMES
6dad717f2853        mvisonneau/yubikey-server:0.1   "/usr/bin/supervisor   2 seconds ago       Up 1 seconds        0.0.0.0:8000->80/tcp   yubikey-server
```

Check if it does reply on the exported port :
```bash
sudo curl http://localhost:8000/wsapi/decrypt
ERR No OTP provided
```

- Almost there ! Now you just have to program your Yubikeys with the generated values.
- You can also shut the rng-tools daemon, it is not required anymore.

## Use case : 2 STEP Verification (SSH)

Let's say you wanna build a 2 step verification onto a specific machine that is not supposed to access internet directly or you just don't wanna rely onto the *Yubicloud* service availability. This example is for you !

### Requirements

This method is based on the new functionnalities of **OpenSSH 6.2**. It should not work on older versions.

### Environment

- Ubuntu 		14.04 LTS x64
- OpenSSH		6.6
- Docker 		1.5.0
- rng-tools 	4.0
- libpam-yubico 2.18.1

### 1- Installation of Docker

```bash
curl -sSL https://get.docker.com/ubuntu/ | sudo sh
```

### 2- Installation of rng-tools
```bash
sudo apt-get install rng-tools
```

### 3- Installation of the libpam-yubico
```bash
sudo add-apt-repository ppa:yubico/stable
sudo apt-get update
sudo apt-get install libpam-yubico
```

### 4- Build the container & Configure your Keys

Please refer to the **Usage** section of this README

### 5- Run the container

In this case, we want our container to be automatically started at boot and always up. In order to do so we have to adjust the run command :
```bash
sudo docker run --name yubikey-server -d -p 8000:80 <yourname>/yubikey-server:0.1
```

### 6- Configure SSH
```bash
### /etc/ssh/sshd_config
ChallengeResponseAuthentication no
PubkeyAuthentication no
PasswordAuthentication no
AuthenticationMethods publickey,password
```
```bash
service ssh restart
```

### 7- Configure PAM

Create a new file */etc/pam.d/yubi-auth* : Replace {ID} and {KEY} with your *Client Info* you got when you created the container.

```bash
### /etc/pam.d/yubi-auth
auth    required        pam_yubico.so id={ID} key={KEY} authfile=/etc/yubimap urllist=http://localhost:8000/wsapi/2.0/verify debug
```

*NB : For now debug mode is activated. For security reasons after you are done testing your installation you should disable it by removing the `debug` at the end of the line.*

The debug file also has to be manually created :
```bash
touch /var/run/pam-debug.log
chmod go+w /var/run/pam-debug.log
```

Into the PAM configuration of sshd you should comment the line `@include common-auth` and add the following `@include yubi-auth`

```bash
### /etc/pam.d/sshd
#@include common-auth
@include yubi-auth
```

### 8- Configure the mapping between users and keys

Creation of a file called /etc/yubimap with mod 400, replace the {publickey:keyn} with the values of the keys you got :

```bash
### /etc/yubimap
user1:{publickey:key1}
user2:{publickey:key2}
```

```bash
sudo chmod 400 /etc/yubimap
```

*NB: The library also supports LDAP in order to manage the relationship*

### 9- Results

You should now be able to login onto your machine only if you have a correct Yubikey defined with your user. I suggest to keep a terminal open with your current session if you do not have physical access on the machine.

## Roadmap
- Document how to program the Yubikeys
- Create a Puppet module doing about the same
- Make a Vagrantfile based on Ubuntu 14.04 LTS
- Enhancement of keys management
- Add the possibility to join an existing key file to add some more keys

## Contribute

In order to contribute, you can fork and send PR.

## License

Maxime VISONNEAU - @mvisonneau

This script is licensed under the Apache License, Version 2.0.

See http://www.apache.org/licenses/LICENSE-2.0.html for the full license text.