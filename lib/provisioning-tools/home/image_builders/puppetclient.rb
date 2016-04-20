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

  run('install rc.local') do
    open("#{spec[:temp_dir]}/etc/rc.local", 'w') do |f|
      f.puts "#!/bin/sh -e\n" \
        "echo 'Running rc.local' | logger\n" \
        "echo 'Run ntpdate'\n" \
        "(/usr/sbin/ntpdate -b -v -d -s ci-1.youdevise.com 2>&1 | tee -a /tmp/bootstrap.log || exit 0)\n" \
        "echo 'Regenerating SSH hostkeys'\n" \
        "/bin/rm /etc/ssh/ssh_host_*\n" \
        "/usr/sbin/dpkg-reconfigure openssh-server\n" \
        "tcpdump -i any -e -n -s0 port 8140 -w /tmp/out.pcap &" \
        "echo 'Running puppet agent'\n" \
        "puppet agent --debug --verbose --waitforcert 10 --onetime 2>&1 | tee -a /tmp/bootstrap.log\n" \
        "killall tcpdump" \
        "echo \"#!/bin/sh -e\\nexit 0\" > /etc/rc.local\n" \
        "echo 'Finished running rc.local'\n" \
        "exit 0\n"
    end
  end

  run("hack some debugging into the gold image") do
    cmd("cp " \
        "/usr/local/lib/site_ruby/timgroup/provisioning-tools/home/puppet_network_http_pool.rb " \
        "#{spec[:temp_dir]}/usr/lib/ruby/vendor_ruby/puppet/network/http/pool.rb")
  end
end
