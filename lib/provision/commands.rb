module Provision::Commands
  def initialize(options)
  end

  def cmd(cmd)
    Provision.log.debug("running command #{cmd}")
    if ! system("#{cmd}  >> console.log 2>&1")
      raise Exception.new("command #{cmd} returned non-zero error code")
    end
  end

  def chroot(dir, cmd)
    cmd("chroot #{dir} /bin/bash -c '#{cmd}'")
  end

  def chroot2(cmd)

print self.instance_variables()
    cmd("chroot #{temp_dir} /bin/bash -c '#{cmd}'")
  end

  def cat(file, content)
    open(file, 'w') { |f|
      f.puts(content)
    }
  end

  def install(dir, package)
    chroot(dir, "DEBIAN_FRONTEND=noninteractive apt-get -y --force-yes install #{package}")
  end

  def hostname(hostname)
  end
end
