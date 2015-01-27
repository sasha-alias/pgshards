# pgshards

Installation and configuration of sharded Postgresql cluster on Ubuntu 14.04 trusty.

The installed clusters comprised of configured Postgresql, Pl/Proxy, PgBouncer and PGQ.


## Running demo cluster

In order to try it out you need a VirtualBox and Vagrant installed.

    git clone https://github.com/sasha-alias/pgshards
    cd pgshards
    vagrant box add  ubuntu/trusty64
    vagrant up

After it's finished you should be able to connect to postgresql demo cluster using the following connectstring:

    psql postgresql://demo:demo@localhost:5455/demo

In order to connect to the host via ssh use the command:

    vagrant ssh


## Repository Structure

- 9.3 - ansible roles for installing cluster based on Postgresql 9.3
- inventory - ansible inventory files responsible for insfrastructure description
- application.yaml - demo application descriptor (depends on pgbuild)
- bootstrap.sh - vagrant provisioning script
- play_install.yaml - ansible playbook for cluster setup
- Vagrantfile - Vagrantfile )
