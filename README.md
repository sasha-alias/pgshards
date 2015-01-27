# pgshards

Installation sharded Postgresql database and utilities on Ubuntu 14.04 trusty.

Repository contains ansible roles for installation and configuration sharded Postgresql cluster.

The installed clusters comprised of configured Postgresql, Pl/Proxy, PgBouncer and PGQ.


## Running demo cluster

In order to try it out you need a VertualBox and Vagrant installed.

    git clone https://github.com/sasha-alias/pgshards
    cd pgshards
    vagrant box add  ubuntu/trusty64
    vagrant up

## Repository Structure

- 9.3 - ansible roles for installing cluster based on Postgresql 9.3
- inventory - ansible inventory files responsible for insfrastructure description
- application.yaml - demo application descriptor (depends on pgbuild)
- bootstrap.sh - vagrant provisioning script
- play_install.yaml - ansible playbook for cluster setup
- Vagrantfile - Vagrantfile )
