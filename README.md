# bifrozt-ansible

---

This was forked from Ziemeck (https://github.com/Ziemeck/bifrozt-ansible) who converted my original Bifrozt project into and Ansible playbook.

---

#### Pre-deployment tasks

This ansible playbook makes the following assumptions
- Ansible has been installed (http://docs.ansible.com/ansible/intro_installation.html) on a separate host
- The target machine(s) to which Bifrozt should be deployed allows root access with public-private keys
- The public key for the root user has been installed into the /root/.ssh directory 
- Any host to which Bifrozt should be deployed has been added to the hosts file within this directory

---

#### Deployment

Once all pre-deployment tasks have been completed and you are logged in to the machine on which ansible has been installed.
Change into the 'bifrozt-ansible' directory and execute the following command:
<pre>
ansible-playbook playbook.yml -i hosts
</pre>

---

#### Requirements

Recomended
- A newer *nix like system (only tested on Ubuntu 14.04 so far)
- 10 GB free space or more
- 2 GB memory
- 2 NIC

---




