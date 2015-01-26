# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
  config.vm.define :shards do |shards|
      shards.vm.box = "ubuntu/trusty64"
      shards.vm.network :forwarded_port, host: 5455, guest: 5432
      shards.vm.provider "virtualbox" do |vb|
        vb.memory = "2048"
      end
      shards.vm.provision :shell, path: "bootstrap.sh"
  end
end
