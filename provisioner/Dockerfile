FROM ubuntu:latest as ansible

ENV DEBIAN_FRONTEND=noninteractive
ENV ANSIBLE_VAULT_PASSWORD_FILE="{{CWD}}/.vault_pass"

RUN apt-get update \
  && apt-get install -y python3-pip python3-dev sshpass tmux \
  && cd /usr/local/bin \
  && ln -s /usr/bin/python3 python \
  && pip3 --no-cache-dir install --upgrade pip \
  && rm -rf /var/lib/apt/lists/* \
  && pip3 install ansible-core ansible-cmdb mkdocs-material

RUN mkdir /ansible
WORKDIR /ansible

RUN ansible-galaxy collection install community.general community.crypto ansible.posix

CMD [ "ansible-playbook", "playbooks/main-program.yaml", \
       "--extra-vars", \
       "profile_path='/ansible/ansible_profiles/loop-flow/main.yaml' \
       profile_dir='/ansible/ansible_profiles/loop-flow/' \
       ansible_user='max' \
       squash='false' \
       debug_output='true'"]

# docker run --mount type=bind,source="$(pwd)",target=/ansible provisioner