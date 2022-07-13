## Ansible Provisioning

- It's generally best right now to use 1 file per set of actions in the same family (file manipulation, users, groups, installing packages)

  This is a byproduct of how the demo script work right now. Certain design choices with the demo mean that steps in the automation pipeline run in a pre-determined order of events which can cause race-condition-like issues when combining multiple roles into one file (setting up groups, installing packages, and running commands all in the same yaml file will not always execute int he orger expected).

  The cause is that the demo uses a fore-each loop to traverse the profile folder and execute each file found in order - when migrating to python we can just use one file and execute each element in order as they appear. We could do that in bash but I dont want to write that logic in shell right nowand increase the tech-debt.

##  Build Your Own Profile

1. For any action you want the system to perform, create a yaml file starting with an index followed by an underscore and a descriptive title.

    Example:

    ```zsh
    # change to the profiles directory
    cd profiles

    # create a new profile by creating a new directory
    mkdir my_profile

    # enter the directory
    cd my_profile

    # create the first step in the automation pipeline
    touch 0_groups.yaml
    ```

2. In the `0_groups.yaml` file, we now describe the actions the system should take.
In this example I'm setting up a generic set of groups, notably lxd and docker 
which will allow me to run docker later without sudo.

    ```yaml
    Groups:
      - Name: automation
        State: present
      - Name: adm
        State: present
      - Name: cdrom
        State: present
      - Name: sudo
        State: present
      - Name: dip
        State: present
      - Name: plugdev
        State: present
      - Name: lxd
        State: present
      - Name: docker
        State: present
    ```

3. Next, lets create `1_users.yaml` and set up the users we will need:

    ```yaml
    Users:
    - Name: "vmadmin"
      State: present
      Comment: "automation user, dynamically altered at runtime - dont change"
      Shell: /bin/bash
      Create_Home: yes
      SSH_Key_file: no
      System: yes
      Groups: "sudo, docker"
      Password: "{{ 'password' | password_hash('sha512') }}"
    ```

4. As you can probably imagine, there are a host of modules that can be used to define subsequent steps for the automation pipeline. Some more examples are:

    - Run a command on the remote client

        ```yaml
        Commands:
          - Command: ""
            become:
            become_user:
            become_method:
        ```
    - Download a file or clone a repository on a remote client

        ```yaml
        Downloads:
          - Name:
            URL: ""
            Destination: ""
        Repos:
          - Source:
            Destination:
            Branch: ""
        ```
        There's no magic or anything, we're just defining a list of similar actions using ansible roles, then letting the tooling make it happen using some loopy-loops. 

## Available Ansible Roles and Options


1. Apt Keys

- Uses the built-in [apt_key](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_key_module.html) module

  ```yaml
  ---
  Apt_Keys:
    - Name:
      URL:
  ```

2. Apt packages

  - uses the built-in [apt](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html) module

    To enable squash installs (an optimized process that accepts a list of packages), pass the squash variable to ansible via the extravars flag. State, Hold, and Version flags are not support for squash install and ansible to revert to normal install when those flags are present. Ansible will automatically translate the YAML into a string list at runtime.

    ```yaml
    ---
    Apt_Pass_1:
      - Name:
        State: present/absent
        Hold: True/False
        Version: (optional)
    ```

3. Apt Repos

- Uses the builtin [apt_repository](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_repository_module.html) module

  ```yaml
  ---
  Apt_Repos:
    - Name:
      URL:
  ```

4. Apt Keys

- uses the builtin [apt_key](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_key_module.html) module

  ```yaml
  ---
  Apt_Keys
    - Name:
      URL: 
  ```

5. Brew Packages

- uses the [community.general.homebrew](https://docs.ansible.com/ansible/latest/collections/community/general/homebrew_module.html) module

    Brew is a tricky package manager because it cannot be installed as root, and requires updating the $PATH environment variable which is a pain with Ansible. This means that the install process for Brew requires the use of the `git_clone`, `files`, and `commands` modules in a specific order.

  ```yaml
  ---
  Brew_Path: ~/.path/to/brew
  Brew:
    - Name: some_package
      State: present / absent
    - Name: homebrew/cask/some_pckage
      State: present / absent
  ```

6. Snap Packages

- Uses the [community.general.snap](https://docs.ansible.com/ansible/latest/collections/community/general/snap_module.html) module

  ```yaml
  ---
  Snap:
    - Name: 
      State: present / absent
    - Name: 
      Classic:
    - Name: 
      Channel: 
  ```

7. Pip

- Uses the builtin [pip](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/pip_module.html) module
- ToDo: add support for requirements.txt files and virtual envs

  ```yaml
  ---
  Pip:
    - Name:
      Version: (optional)
  ```

8. Clone a git repo

- Uses the [ansible.builtin.git](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/git_module.html) module

  ```yaml
  Repos:
    - Source: repo url
      Destination: /path/to/destination
      Branch: 
  ```

9. Download files

- Uses the builtin [get_url](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/get_url_module.html) module

  ```yaml
  ---
  Downloads:
    - Name: 
      URL: url to download
      Destination: /path/to/destination
  ```

10. Manipulate Files

- [ansible.builtin.file](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/file_module.html)
- [ansible.builtin.unarchive](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/unarchive_module.html)
- [ansible.builtin.copy](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/copy_module.html)

  ```yaml
  ---
  Files:
   - Name: Unarchive a file
     Archive: ""
     Dest: ""
     State: extract
     Become_User: some_user
  
   - Name: Create a new directory
     Path: ""
     Recurse:
     State: directory
     Become_User: some_user
    
   - Name: Delete a directory
     Path: ""
     State: absent
     Become_User: some_user
  
   - Name: Create a Simlink
     Source: ""
     Dest: ""
     State: link
     Become_User: some_user
  
   - Name: Change file ownership, group and permissions
     Path: ""
     Mode: ""
     Group: ""
     State: permissions
     Become_User: some_user
  
   - Name: Copy files within the remote client
     Source: ""
     Dest: ""
     Mode: ""
     State: copy
     Become_User: some_user
  ```

11. Run a command

- Uses the [ansible.builtin.command](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/command_module.html) module

  Delegated commands are WiP/semi-functional, documentation about delegated command can be found [HERE](https://docs.ansible.com/ansible/latest/user_guide/playbooks_delegation.html)

  ```yaml
  Commands:
    - Command: "a normal user command"

    - Command: "a sudo command"
      Become:
      Become_User:
      Become_Method:

    - Command: "a delegated command"
      Delegated_Host: 
      Become:
      Become_User:
      Become_Method:
  ```

12. Manage User Accounts

- Uses the builtin [user](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/user_module.html) module
- Uses the [community.crypto.openssh_keypair](https://docs.ansible.com/ansible/latest/collections/community/crypto/openssh_keypair_module.html) module 
- passwords must be hashed via sha512. For example: ```"{{ 'password' | password_hash('sha512') }}"```
- system users will get sudoless root by default

  ```yaml
  ---
  Users:
  - Name: User Name
    State: present / absent
    Comment: descriiption text
    Shell: user's default shell
    Create_Home: yes / no
    SSH_Key_file: no ( we use the community.crypto.openssh_keypair module instead )
    System: yes / no (is a system account)
    Groups: ""
    Password: hashed password value
  ```

13. Manage Groups

- Uses [ansible.builtin.user](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/user_module.html) module

  ```yaml
  ---
  Groups:
    - Name: 
      State: present / absent
  ```

14. Update Package Cache

- uses the built-in [apt](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html) module

  ```yaml
  ---
  Package_Update:
    - Update: 
      Autoremove: 
  ```

15. Upgrade Packages

- uses the built-in [apt](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/apt_module.html) module

  ```yaml
  ---
  Package_Upgrade:
    - Method: choices are 'dist' 'full', 'no', 'safe', 'yes'
  ```

16. Copy a script from the host and execute it on the remote

- Uses the builtin [script](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/script_module.html) module
  
  ```yaml
  ---
  Scripts:
    - Script: "/path/to/script.sh"
      Become:
      Become_User:
      Become_Method:
  ```

17. Sync the shared Diredctory and Files from local server to remote

- Uses the [synchronize](https://docs.ansible.com/ansible/2.3/synchronize_module.html) modue which is a just a wrapper around rsync.

  ```yaml
  ---
  Sync:
    - name: Transfer files/folder from ServerA to ServerB
      Dest: /destinaton/path
  ```


## __Linux Heads Up:__

- this linux image uses a non-standard /etc/sudoers config without requiretty
- Ansible pipelining is enabled in the included config. To enable it on your system, place the file in one of the ways directed below:

    - `ANSIBLE_CONFIG` (environment variable if set)
    - `ansible.cfg` (in the current directory)
    - `~/.ansible.cfg` (in the home directory)
    - `/etc/ansible/ansible.cfg`
