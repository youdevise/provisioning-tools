require 'provision/dns'
require 'provision/dns/dnsmasq'
require 'tmpdir'
require 'provision/core/machine_spec'

class Provision::DNS::DNSMasq
  def max_ip
    @max_ip.to_s
  end
  def hosts_by_name
    @by_name
  end
end

describe Provision::DNS::DNSMasq do

  it 'constructs once' do
    Dir.mktmpdir {|dir|
      Provision::DNS::DNSMasq.files_dir = dir
      File.open("#{dir}/hosts", 'w') { |f| f.write "# Example hosts file\n127.0.0.1 localhost\n" }
      thing = Provision::DNS.get_backend("DNSMasq")
      ip = thing.allocate_ip_for(Provision::Core::MachineSpec.new(:hostname => "example", :domain => "youdevise.com"))
      ip.to_s.should eql("192.168.5.2")
      other = thing.allocate_ip_for(Provision::Core::MachineSpec.new(:hostname => "example2", :domain => "youdevise.com"))
      other.to_s.should eql("192.168.5.3")
      first_again = thing.allocate_ip_for(Provision::Core::MachineSpec.new(:hostname => "example", :domain => "youdevise.com"))
      first_again.to_s.should eql("192.168.5.2")

      new_thing = Provision::DNS.get_backend("DNSMasq")
      new_thing_ip = new_thing.allocate_ip_for(Provision::Core::MachineSpec.new(:hostname => "example", :domain => "youdevise.com"))
      new_thing_ip.to_s.should eql("192.168.5.2")

      new_thing.max_ip.should eql("192.168.5.3")
      new_thing.hosts_by_name.should eql({
        "example.youdevise.com" => "192.168.5.2",
        "example2.youdevise.com" => "192.168.5.3"
      })
    }
  end

  it 'parses wacky /etc/hosts' do
    Dir.mktmpdir {|dir|
      Provision::DNS::DNSMasq.files_dir = dir
      File.open("#{dir}/hosts", 'w') { |f| f.write "192.168.5.5\t    fnar fnar.example.com\n192.168.5.2   \t boo.example.com\tboo   \n# Example hosts file\n192.168.5.1 flib   \n" }
      thing = Provision::DNS.get_backend("DNSMasq")
      thing.hosts_by_name.should eql({
          "fnar" => "192.168.5.5",
          "fnar.example.com" => "192.168.5.5",
          "boo.example.com" => "192.168.5.2",
          "boo" => "192.168.5.2",
          "flib" => "192.168.5.1"
      })
      thing.max_ip.should eql("192.168.5.5")
    }
  end

  it 'writes hosts and ethers out' do
    Dir.mktmpdir {|dir|
      Provision::DNS::DNSMasq.files_dir = dir
      File.open("#{dir}/hosts", 'w') { |f| f.write "\n" }
      thing = Provision::DNS.get_backend("DNSMasq")
      thing.allocate_ip_for(Provision::Core::MachineSpec.new(:hostname => "example", :domain => "youdevise.com"))
      File.open("#{dir}/ethers", 'r') { |f| f.read.should eql("52:54:00:01:55:3f 192.168.5.2\n") }
      File.open("#{dir}/hosts", 'r') { |f| f.read.should eql("\n192.168.5.2 example.youdevise.com\n") }
    }
  end
end
