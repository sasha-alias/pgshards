apt-get update
apt-get install ansible -y
apt-get install git -y
apt-get install python-psycopg2 -y
git clone https://github.com/sasha-alias/pgbuild
python /home/vagrant/pgbuild/pgbuild.py build /vagrant/application.yaml /vagrant/.build --format=ansible -o
export ANSIBLE_ROLES_PATH=/vagrant/9.3/roles:/vagrant/.build
ansible-playbook /vagrant/play_install.yaml -i /vagrant/inventory/vagrant/hosts
