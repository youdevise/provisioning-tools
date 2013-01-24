require 'provision'

#require 'net/ssh'

describe Provision do
  def wait_for_vm(ip_address)
    5.times do
      begin
        print ssh(ip_address,"uname -a")
        return
      rescue
      end
      sleep 1
    end
    raise "VM never started"
  end

  def ssh(ip_address, cmd)
    #    Net::SSH.start(ip_address(), 'root', :password => "root", :paranoid => Net::SSH::Verifiers::Null.new) do |ssh|
    #     hostname = ssh.exec!(cmd).chomp
    #  end
    raise "SSH ERROR"
  end

  it 'after building a test vm I am able to login and the hostname is correct' do
    descriptor = Provision.new.vm(:imagesdir=>"build/images", :hostname=>"RANDOMX", :template=>"ubuntuprecise",:thread_number=>1)
    wait_for_vm(descriptor.ip_address)
    ssh(descriptor.ip_address, "hostname").should eql("RANDOMX")
  end

end
