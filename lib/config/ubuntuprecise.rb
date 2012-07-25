require 'provision/image/catalogue'
require 'provision/image/commands'

define "ubuntuprecise" do
  extend Provision::Image::Commands
  conventions()
  imagefile = "/images/#{hostname}.img"

  run("loopback devices") {
    cmd "mkdir #{temp_dir}"
    cmd "kvm-img create -fraw #{imagefile} 3G"
    cmd "losetup /dev/#{loop0} #{imagefile}"
    cmd "parted -sm /dev/#{loop0} mklabel msdos"
    supress_error.cmd "parted -sm /dev/#{loop0} mkpart primary ext3 1 100%"
    cmd "kpartx -a -v /dev/#{loop0}"
    cmd "mkfs.ext4 /dev/mapper/#{loop0}p1"
  }

  cleanup {
   while(`dmsetup ls | grep #{loop0}p1 | wc -l`.chomp != "0")
     cmd "kpartx -d /dev/#{loop0}"
     sleep(0.1)
   end
   cmd "udevadm settle"

   while(`losetup -a | grep /dev/#{loop0} | wc -l`.chomp != "0")
     cmd "losetup -d /dev/#{loop0}"
     sleep(0.1)
   end

   while (`ls -d  #{temp_dir} 2> /dev/null | wc -l`.chomp != "0")
     cmd "umount #{temp_dir}"
     cmd "rmdir #{temp_dir}"
     sleep(0.1)
   end
   cmd "udevadm settle"
 }

  run("loopback devices 2") {
    cmd "losetup /dev/#{loop1} /dev/mapper/#{loop0}p1"
    cmd "mount /dev/#{loop1} #{temp_dir}"
  }

  cleanup {
   while(`losetup -a | grep /dev/#{loop1} | wc -l`.chomp != "0")
     cmd "umount -d /dev/#{loop1}"
     cmd "losetup -d /dev/#{loop1}"
    end
  }

  run("running debootstrap") {
    cmd "debootstrap --arch amd64 precise #{temp_dir} http://aptproxy:3142/ubuntu"
    #cmd "mkdir #{temp_dir}/proc"
    #cmd "mkdir #{temp_dir}/sys"
    #cmd "mkdir #{temp_dir}/dev"
  }


  run("mounting devices") {
    cmd "mount --bind /dev #{temp_dir}/dev"
    cmd "mount -t proc none #{temp_dir}/proc"
    cmd "mount -t sysfs none #{temp_dir}/sys"
  }

  cleanup {
    # FIXME Remove the sleep from here, ideally before dellis sees and stabs me.
    # Sleep required because prior steps do not release their file handles quick enough - or something.


   while(`mount -l | grep #{temp_dir}/proc | wc -l`.chomp != "0")
       cmd "umount #{temp_dir}/proc"
      sleep(0.5)
   end


   while (`mount -l | grep #{temp_dir}/sys | wc -l`.chomp != "0")
     cmd "umount #{temp_dir}/sys"
     sleep(0.5)
   end

   while( `mount -l | grep #{temp_dir}/dev | wc -l`.chomp != "0")
      cmd "umount #{temp_dir}/dev"
      sleep(0.5)
   end
  }
  run("set locale") {
    open("#{temp_dir}/etc/default/locale", 'w') { |f|
      f.puts 'LANG="en_GB.UTF-8"'
    }

    chroot "locale-gen en_GB.UTF-8"
  }

  run("set timezone") {
    open("#{temp_dir}/etc/timezone", 'w') { |f|
      f.puts 'Europe/London'
    }

    chroot "dpkg-reconfigure --frontend noninteractive tzdata"
  }

  run("set hostname") {
    open("#{temp_dir}/etc/hostname", 'w') { |f|
      f.puts "#{hostname}"
    }
    chroot "hostname -F /etc/hostname"
  }

  run("install kernel and grub") {
    chroot "apt-get -y --force-yes update"
    apt_install "linux-image-virtual"
    apt_install "grub-pc"

    cmd "mkdir -p #{temp_dir}/boot/grub"

    open("#{temp_dir}/boot/grub/device.map", 'w') { |f|
      f.puts "(hd0) /dev/#{loop0}"
      f.puts "(hd0,1) /dev/#{loop1}"
    }

    kernel_version = "3.2.0-23-virtual"
    kernel = "/boot/vmlinuz-#{kernel_version}"
    initrd = "/boot/initrd.img-#{kernel_version}"
    uuid = `blkid -o value /dev/mapper/#{loop0}p1 | head -n1`.chomp

    open("#{temp_dir}/boot/grub/grub.cfg", 'w') { |f|
      f.puts "
          set default=\"0\"
          set timeout=1
          menuentry 'Ubuntu, with Linux #{kernel_version}' --class ubuntu --class gnu-linux --class gnu --class os {
          insmod part_msdos
          insmod ext2
          set root='(hd0,1)'
          linux #{kernel} root=/dev/disk/by-uuid/#{uuid} ro
          initrd #{initrd}
          }"
    }

    chroot "grub-install --no-floppy --grub-mkdevicemap=/boot/grub/device.map /dev/#{loop0}"
  }

  run("set root password") {
    chroot "echo 'root:root' | chpasswd"
  }

  run("set up basic networking") {
    open("#{temp_dir}/etc/network/interfaces", 'w') { |f|
      f.puts "
     # The loopback network interface
     auto lo
     iface lo inet loopback
     # The primary network interface
     auto eth0
     iface eth0 inet dhcp
       "
    }
  }

  run("install misc packages") {
    apt_install "acpid openssh-server curl vim"
  }

  # A few daemons hang around at the end of the bootstrapping process that prevent us unmounting.
  cleanup {
    chroot "/etc/init.d/acpid stop"
    chroot "/etc/init.d/cron stop"
  }

  run("configure youdevise apt repo") {
    open("#{temp_dir}/etc/apt/sources.list.d/youdevise.list", 'w') { |f|
      f.puts "deb http://apt/ubuntu stable main\ndeb-src http://apt/ubuntu stable main\n"
    }

    chroot "curl -Ss http://apt/ubuntu/repo.key | apt-key add -"
  }



end
