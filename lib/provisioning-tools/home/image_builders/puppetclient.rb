define "puppetclient" do
  copyboot

  run("install puppet") do
    apt_install "puppet"
    open("#{spec[:temp_dir]}/etc/puppet/puppet.conf", 'w') do |f|
      f.puts "[main]\n" \
        "  vardir                         = /var/lib/puppet\n" \
        "  logdir                         = /var/log/puppet\n" \
        "  rundir                         = /var/run/puppet\n" \
        "  ssldir                         = $vardir/ssl\n" \
        "  factpath                       = $vardir/lib/facter\n" \
        "  pluginsync                     = true\n" \
        "  environment                    = masterbranch\n" \
        "  configtimeout                  = 3000\n" \
        "  preferred_serialization_format = msgpack\n" \
        "  # BUG Fixed in Puppet 4.0 (https://tickets.puppetlabs.com/browse/PUP-1035)\n" \
        "  pluginsource                   = puppet:///plugins\n" \
        "  pluginfactsource               = puppet:///pluginfacts\n"
    end
  end

  run('setup one time password') do
    require 'rubygems'
    require 'rotp'

    totp = ROTP::TOTP.new(config[:otp_secret], :interval => 120)
    onetime = totp.now
    open("#{spec[:temp_dir]}/etc/puppet/csr_attributes.yaml", 'w') do |f|
      f.puts "extension_requests:\n" \
        "  pp_preshared_key: #{onetime}\n"
    end
  end

  run('stamp metadata') do
    require 'rubygems'
    require 'facter'
    require 'puppet'
    Puppet.initialize_settings
    Facter::Util::Config.ext_fact_loader = Facter::Util::DirectoryLoader.loader_for('/etc/facts.d/')
    cmd "mkdir -p #{spec[:temp_dir]}/etc/facts.d"
    open("#{spec[:temp_dir]}/etc/facts.d/provision_metadata.fact", 'w') do |f|
      f.puts "kvm_host=#{Facter.value(:hostname)}\n" \
             "rack=#{Facter.value(:rack)}\n" \
             "provision_date=#{DateTime.now.iso8601}\n" \
             "provision_secs_since_epoch=#{DateTime.now.strftime('%s')}\n"
    end
  end

  run('install rc.local') do
    open("#{spec[:temp_dir]}/etc/rc.local", 'w') do |f|
      f.puts "#!/bin/sh -e\n" \
        "if [ -e /var/lib/firstboot ]; then exit 0; fi\n" \
        "echo 'Running rc.local' | logger\n" \
        "echo 'Run ntpdate'\n" \
        "(/usr/sbin/ntpdate -b -v -d -s 10.108.11.97 2>&1 | tee -a /tmp/bootstrap.log || exit 0)\n" \
        "echo 'Regenerating SSH hostkeys'\n" \
        "/bin/rm /etc/ssh/ssh_host_*\n" \
        "/usr/sbin/dpkg-reconfigure openssh-server\n" \
        "echo 'Running puppet agent'\n" \
        "export LANG=en_GB.UTF-8\n" \
        "puppet agent --debug --verbose --waitforcert 10 --onetime 2>&1 | tee -a /tmp/bootstrap.log\n" \
        "touch /var/lib/firstboot\n" \
        "echo 'Finished running rc.local'\n" \
        "exit 0\n"
    end
  end
end
