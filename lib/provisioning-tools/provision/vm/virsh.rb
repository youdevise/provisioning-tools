require 'provisioning-tools/provision/vm/namespace'
require 'provisioning-tools/provision'
require 'erb'
require 'ostruct'

class Provision::VM::Virsh
  def initialize(config, executor = nil)
    @config = config
    @executor = executor
    @executor = ->(cli) do
      output = `#{cli}`
      fail("Failed to run: #{cli}") unless $?.success?
      output
    end if @executor.nil?
  end

  def safe_system(cli)
    fail("Failed to run: #{cli}") if system(cli) != true
  end

  def is_defined(spec)
    is_in_virsh_list(spec, '--all')
  end

  def is_running(spec)
    is_in_virsh_list(spec)
  end

  def is_in_virsh_list(spec, extra = '')
    vm_name = spec[:hostname]
    result = `virsh list #{extra} | grep ' #{vm_name} ' | wc -l`
    result.match(/1/)
  end

  def undefine_vm(spec)
    fail 'VM marked as non-destroyable' if spec[:disallow_destroy]
    safe_system("virsh undefine #{spec[:hostname]} > /dev/null 2>&1")
  end

  def destroy_vm(spec)
    fail 'VM marked as non-destroyable' if spec[:disallow_destroy]
    safe_system("virsh destroy #{spec[:hostname]} > /dev/null 2>&1")
  end

  def shutdown_vm(spec)
    fail 'VM marked as non-destroyable' if spec[:disallow_destroy]
    safe_system("virsh shutdown #{spec[:hostname]} > /dev/null 2>&1")
  end

  def shutdown_vm_wait_and_destroy(spec, timeout = 60)
    shutdown_vm(spec)
    begin
      wait_for_shutdown(spec, timeout)
    rescue Exception => e
      destroy_vm(spec)
    end
  end

  def start_vm(spec)
    return if is_running(spec)
    safe_system("virsh start #{spec[:hostname]} > /dev/null 2>&1")
  end

  def wait_for_shutdown(spec, timeout = 120)
    timeout.times do
      return if !is_running(spec)
      sleep 1
    end

    fail "giving up waiting for #{spec[:hostname]} to shutdown"
  end

  def generate_virsh_xml(spec, storage_xml = nil)
    template_file = if spec[:kvm_template]
                      "#{Provision.templatedir}/#{spec[:kvm_template]}.template"
                    else
                      "#{Provision.templatedir}/kvm.template"
                    end
    template = ERB.new(File.read(template_file))

    binding = VirshBinding.new(spec, @config, storage_xml)
    begin
      template.result(binding.get_binding)
    rescue Exception => e
      print e
      print e.backtrace
      nil
    end
  end

  def write_virsh_xml(spec, storage_xml = nil)
    to = "#{spec[:libvirt_dir]}/#{spec[:hostname]}.xml"
    File.open to, 'w' do |f|
      f.write generate_virsh_xml(spec, storage_xml)
    end
    to
  end

  def define_vm(spec, storage_xml = nil)
    to = write_virsh_xml(spec, storage_xml)
    safe_system("virsh define #{to} > /dev/null 2>&1")
  end

  def check_vm_definition(spec, storage_xml = nil, ignore_safe_vm_diffs = false)
    require 'provisioning-tools/util/xml_utils'

    spec_xml = generate_virsh_xml(spec, storage_xml)
    actual_xml = @executor.call("virsh dumpxml #{spec[:hostname]}")

    differences = Util::VirshDomainXmlDiffer.new(spec_xml, actual_xml, ignore_safe_vm_diffs).differences
    fail "actual vm definition differs from spec\n  #{differences.join("\n  ")}" unless differences.empty?
  end
end

class VirshBinding
  attr_accessor :spec, :config, :storage_xml

  def initialize(spec, config, storage_xml = nil)
    @spec = spec
    @config = config
    @storage_xml = storage_xml
  end

  def get_binding
    binding
  end
end
