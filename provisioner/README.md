# Ansible

Ansible roles that execute actions defined in a yaml file.

## Provision localhost

  1. Clone this repo.
  2. `cd public-infra/ansible`
  3. `bash provision.sh`

## Ansible Profiles

  - Existing profiles can be found in the [ansible_profiles](public-infra/ansible/ansible_profiles) directory

  - Create your own profile [HERE](onboardme/configs/ansible_profiles/README.md)


## Roles

- Each role is just a brick of basic logic to loop over with a list.

- you can find a list of available roles and their fields/values in [ansible_profiles/README.md](ansible/configs/ansible_profiles/README.md)

## Flow:

1. `/profile/0_step.yaml` contains a list of actions of the same type.
    
    For example:

      ```yaml
      # this yaml file contains a list of 2 commands
      ---
      Commands:
        - Command: gpg --dearmor githubcli-archive-keyring.gpg
          Become: yes
          Become_User: vmadmin
          Become_Method: sudo
        - Command: # another command to run
          Become: # pretend to be a specific user yes/no
          Become_User: # the user to pretend to be
          Become_Method: # how to do it, sudo/su
      ```

2. `ansible/demo.sh` passes `/profile/0_step.yaml` to ansible as `-extra-vars "profile_path='${PROFILE_PATH}'`.

    ```zsh
    # provision the Host with an ansible profile

        for file in /"${DEMO_DIR}"/*.yaml
        do
            export PROFILE_PATH=$file

            echo "running $file ..."
            time ansible-playbook -i $ANSIBLE_INVENTORY_FILE \
                $ANSIBLE_PLAYBOOK \
                -u $ANSIBLE_REMOTE_USER \
                --extra-vars \
                "profile_path='${PROFILE_PATH}' \
                ssh_key_path='${VM_KEY_FILE}' \
                synced_directory='${SYNCED_DIR}' \
                ansible_user='$VM_USER' \
                squash='${SQUASH}' \
                debug_output='${DEBUG}' \
                $VERBOSITY"

        done
    ```

3. for each item in the list, `ansible/playbooks/main-program.yaml` will execute the appropriate ansible function

    ```yaml
      tasks:
      - name: git_clone
        include_role:
          name: git_clone
        when:
          - hostvars['localhost'].profile_json['Repos'] is defined
          - (hostvars['localhost'].profile_json['Repos']|length>0)

      - name: download items
        include_role:
          name: downloads
        when:
          - hostvars['localhost'].profile_json['Downloads'] is defined
          - (hostvars['localhost'].profile_json['Downloads']|length>0)
    ```


## Mitogen Optimizations

Mitogen’s main feature is enabling your Python program to self-replicate and control/communicate with new copies of itself running on remote machines, using only an existing installed Python interpreter and SSH client. (something that by default can be found on almost all contemporary machines in the wild) To accomplish this, Mitogen uses a single 400 byte SSH command line and 8KB of its own source code sent to stdin of the remote SSH connection.

  - [Guide](https://www.toptechskills.com/ansible-tutorials-courses/speed-up-ansible-playbooks-pipelining-mitogen/)

  - [Mitogen for Ansible](https://mitogen.networkgenomics.com/ansible_detailed.html)

  - [download](https://networkgenomics.com/try/mitogen-0.2.9.tar.gz)

  - Be aware that mitogen is on a much slower cadence thn ansible and does not support the latest version.
      
      > # ERROR! Your Ansible version (2.11.7) is too recent. The most recent version
        # supported by Mitogen for Ansible is (2, 10).x. Please check the Mitogen
        # release notes to see if a new version is available, otherwise
        # subscribe to the corresponding GitHub issue to be notified when
        # support becomes available.
    
    
    ```zsh

    pip3 install ansible-base==2.10.16

    wget https://networkgenomics.com/try/mitogen-0.2.9.tar.gz

    tar -xvf mitogen-0.2.9.tar.gz
    rm mitogen-0.2.9.tar.gz

    ```

- Add to `ansible.cfg`:

    ```yaml
    [defaults]
    strategy_plugins = mitogen-0.2.9/ansible_mitogen/plugins/strategy
    strategy = mitogen_linear

    ```

## Pipelining Optimizations

Pipelining, if supported by the connection plugin, reduces the number of network operations required to execute a module on the remote server, by executing many Ansible modules without actual file transfer. 

This can result in a very significant performance improvement when enabled. However this conflicts with privilege escalation (become). For example, when using ‘sudo:’ operations you must first disable ‘requiretty’ in /etc/sudoers on all managed hosts, which is why it is disabled by default. 

This option is disabled if ANSIBLE_KEEP_REMOTE_FILES is enabled. This is a global option, each connection plugin can override either by having more specific options or not supporting pipelining at all.

- Read the docs [here](https://docs.ansible.com/ansible/latest/reference_appendices/config.html)

To enable SSH Multiplexing:

1. in `ansible/ansible.cfg`, add:

    ```yaml
    [ssh_connection]
    pipelining = True
    transfer_method = smart
    retries = 3
    ```

2. To your inventory, `ansible/ansible.cfg` or connection string add:

    ```yaml
          ansible_ssh_common_args: "-o StrictHostKeyChecking=no -o ControlMaster=auto -o ControlPath=~/.ssh/ansible-%r@%h:%p"
    ```

- Warning about multiplexing:

    > When using SSH Multiplexing with longer ControlPersist time, there is a potential trouble, if you sleep your notebook/pc and wake it again with existing MUX connections. By doing this, your connections will be broken, but still staying as Persistent, which will break your ssh connectivity  to the muxed hosts. 

    For fixing it, you will have to kill the SSH [mux] containing processes

    - https://gryzli.info/2019/02/21/tuning-ansible-for-maximum-performance/
