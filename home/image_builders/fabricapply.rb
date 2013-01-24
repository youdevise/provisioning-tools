define "fabricapply" do
  copyboot

  run("run apt-update ") {
    chroot "apt-get -y --force-yes update"
  }

  run("fabricapply") {
    cmd "mkdir #{spec[:temp_dir]}/seed"
    cmd "cp -r #{File.dirname(__FILE__)}/seed  #{spec[:temp_dir]}/"

    open("#{spec[:temp_dir]}/seed/puppet.yaml", "w") {|f|
      f.puts YAML.dump(spec[:enc])
    }

    open("#{spec[:temp_dir]}/seed/puppet.sh", 'w') { |f|
      f.puts """#!/bin/sh -e
puppet apply /seed/manifests/fabric.pp --node_terminus exec --external_nodes /seed/enc.sh --modulepath=/seed/modules 2>&1 | tee /seed/init.log
      """
    }

    cmd "chmod 700 #{spec[:temp_dir]}/seed/puppet.sh"

    open("#{spec[:temp_dir]}/etc/rc.local", 'w') { |f|
      f.puts """#!/bin/sh -e
echo 'Running seed puppet'
/seed/puppet.sh
echo \"#!/bin/sh -e\nexit 0\" > /etc/rc.local
echo 'Finished running fabric puppet'
exit 0
      """
    }
  }
end

