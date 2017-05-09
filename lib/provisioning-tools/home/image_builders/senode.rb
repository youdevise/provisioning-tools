define "senode" do
  copyboot

  run("run apt-update ") do
    chroot "apt-get -y --force-yes update"
  end

  run("mounting devices") do
    cmd "mount --bind /dev #{spec[:temp_dir]}/dev"
    cmd "mount -t proc none #{spec[:temp_dir]}/proc"
    cmd "mount -t sysfs none #{spec[:temp_dir]}/sys"
  end

  cleanup do
    log.debug("cleaning up procs")
    log.debug(`mount -l | grep #{spec[:hostname]}/proc | wc -l`.chomp)
    keep_doing do
      suppress_error.cmd "umount -l #{spec[:temp_dir]}/proc"
    end.until { `mount -l | grep #{spec[:hostname]}/proc | wc -l`.chomp == "0" }

    keep_doing do
      suppress_error.cmd "umount -l #{spec[:temp_dir]}/sys"
    end.until { `mount -l | grep #{spec[:hostname]}/sys | wc -l`.chomp == "0" }

    keep_doing do
      suppress_error.cmd "umount -l #{spec[:temp_dir]}/dev"
    end.until { `mount -l | grep #{spec[:hostname]}/dev | wc -l`.chomp == "0" }
  end

  run("create ci user") do
    chroot "/usr/sbin/adduser ci"
  end

  run("install selenium packages") do
    apt_install "openjdk-7-jdk"
    apt_install "acpid"
    apt_install "xvfb"
    apt_install "dbus"
    apt_install "dbus-x11"
    apt_install "hicolor-icon-theme"
    firefox_version = spec[:firefox_version] || "11.0+build1-0ubuntu4"
    apt_install "firefox=#{firefox_version}"
    chrome_version = spec[:chrome_version] || "22.0.1229.79-r158531"
    apt_install "google-chrome-stable=#{chrome_version}"
    selenium_deb_version = spec[:selenium_deb_version] || spec[:selenium_version] || "2.32.0"
    apt_install "selenium=#{selenium_deb_version}"
    selenium_node_deb_version = spec[:selenium_node_deb_version] || spec[:selenium_node_version] || "3.0.7"
    apt_install "selenium-node=#{selenium_node_deb_version}"
    chroot "update-rc.d selenium-node defaults"
    chroot "sed -i'.bak' -e 's#^securerandom.source=file:/dev/urandom#securerandom.source=file:" \
      "/dev/../dev/urandom#g' /etc/java-7-openjdk/security/java.security"
    chroot "ln -s /usr/lib/firefox/firefox /usr/bin/firefox-bin"
  end

  cleanup do
    chroot "/etc/init.d/dbus stop"
  end

  run("place the selenium node config") do
    host = spec[:selenium_hub_host]
    port = "7799"

    cmd "mkdir -p #{spec[:temp_dir]}/etc/default"
    open("#{spec[:temp_dir]}/etc/default/selenium-node", 'w') do |f|
      f.puts "HUBHOST=#{host}"
      f.puts "HUBPORT=#{port}"
    end
  end
end
