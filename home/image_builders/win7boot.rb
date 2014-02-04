require 'provision/image/catalogue'
require 'provision/image/commands'
require 'socket'

define "win7boot" do
  extend Provision::Image::Commands

  def win7_files
    "/var/lib/provisioning-tools/files/win7gold/"
  end

  def mountpoint
    "#{spec[:temp_dir]}"
  end

  def sysprep_answer_file
    "#{mountpoint}/unattend.xml"
  end

  def start_menu_location
    "#{mountpoint}/ProgramData/Microsoft/Windows/Start\ Menu/Programs/Startup/"
  end

  run("copy gold image") {
    win7_partition_location = 105906176
    cmd "mkdir -p #{spec[:temp_dir]}"
    #cmd "curl --fail -o #{spec[:image_path]} #{spec[:gold_image_url]}"
    cmd "mv #{spec[:gold_image_url]} #{spec[:image_path]}"
    cmd "mount -o offset=#{win7_partition_location} #{spec[:image_path]} #{mountpoint}"
  }

  cleanup {
    cmd "umount #{spec[:temp_dir]}"
  }

  run("install sysprep") {
    FileUtils.cp "#{win7_files}/sysprep/unattend.xml", "#{sysprep_answer_file}"
    FileUtils.cp "#{win7_files}/startmenu/dosysprep.bat", start_menu_location
  }

  run("inject hostname and ip address") {
    gateway = "127.0.0.1"
    spec[:routes].each do |route|
      route =~ /via (.+)$/
      gateway = $1
    end

    dns_domain = spec[:dns_search_path].split(' ')[0]

    spec.interfaces.each do |nic|
      config = spec[:networking][nic[:network].to_sym]
      cmd "sed -i s/<%DNSDOMAIN%>/#{dns_domain}/g #{sysprep_answer_file}"
      cmd "sed -i s/<%DNSSERVER%>/#{spec[:nameserver]}/g #{sysprep_answer_file}"
      cmd "sed -i s/<%IPADDRESS%>/#{config[:address]}/g #{sysprep_answer_file}"
      cmd "sed -i s/<%GATEWAY%>/#{gateway}/g #{sysprep_answer_file}"
    end
  }

  run("configure_launch_script") {
  }

  run("stamp time") {
     tmp_date_file="#{mountpoint}/build-date.txt"
    `date +"%m-%d-%y.%k:%M" > #{tmp_date_file}`
  }

end