module Provision::Core
end

require 'provision/namespace'
require 'provision/core/machine_spec'

class Provision::Core::ProvisioningService
  def initialize(options)
    @vm_service = options[:vm_service] || raise "No :vm_service option passed"
    @image_service = options[:image_service] || raise "No :image_service option passed"
  end

  def provision_vm(spec_hash)
    spec = Provision::Core::MachineSpec.new(spec_hash)
    @vm_service.destroy_vm(spec)
    @vm_service.undefine_vm(spec)
    @numbering_service.allocate_ip_for(spec)
    @image_service.build_image(spec[:template], spec)
    @vm_service.define_vm(spec)
    @vm_service.start_vm(spec)
  end
end
