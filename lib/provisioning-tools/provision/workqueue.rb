require 'logger'
require 'provisioning-tools/provision/namespace'
require 'thread'
require 'provisioning-tools/provision/workqueue/noop_listener'
require 'provisioning-tools/provision/vm/virsh'

class Provision::WorkQueue
  class SpecTask
    attr_reader :spec

    def initialize(spec, &block)
      @spec = spec
      @block = block
    end

    def execute
      @block.call
    end
  end

  def initialize(args)
    @provisioning_service = args[:provisioning_service]
    @worker_count = args[:worker_count]
    @listener = args[:listener]
    @queue = Queue.new
    @logger = args[:logger] || Logger.new(STDERR)
    @config = args[:config]
    @virsh = args[:virsh] || Provision::VM::Virsh.new(@config)
  end

  def launch_all(specs)
    fail "an array of machine specifications is expected" unless specs.kind_of?(Array)
    specs.each do |spec|
      launch(spec)
    end
    process
  end

  def check_all(specs, ignore_safe_vm_diffs)
    fail "an array of machine specifications is expected" unless specs.kind_of?(Array)
    specs.each do |spec|
      check_definition(spec, ignore_safe_vm_diffs)
    end
    process
  end

  def destroy_all(specs)
    fail "an array of machine specifications is expected" unless specs.kind_of?(Array)
    specs.each do |spec|
      destroy(spec)
    end
    process
  end

  def allocate_ip_all(specs)
    fail "an array of machine specifications is expected" unless specs.kind_of?(Array)
    specs.each do |spec|
      allocate_ip(spec)
    end
    process
  end

  def free_ip_all(specs)
    fail "an array of machine specifications is expected" unless specs.kind_of?(Array)
    specs.each do |spec|
      free_ip(spec)
    end
    process
  end

  def create_storage_all(specs)
    fail "an array of machine specifications is expected" unless specs.kind_of?(Array)
    specs.each do |spec|
      create_storage(spec)
    end
    process
  end

  def archive_persistent_storage_all(specs)
    fail "an array of machine specifications is expected" unless specs.kind_of?(Array)
    archive_datetime = Time.now.utc
    specs.each do |spec|
      archive_persistent_storage(spec, archive_datetime)
    end
    process
  end

  def add_cnames(specs)
    specs.each do |spec|
      @queue << SpecTask.new(spec) do
        @provisioning_service.add_cnames(spec)
      end
    end
    process
  end

  def remove_cnames(specs)
    specs.each do |spec|
      @queue << SpecTask.new(spec) do
        @provisioning_service.remove_cnames(spec)
      end
    end
    process
  end

  def launch(spec)
    @queue << SpecTask.new(spec) do
      @logger.info("Provisioning a VM")
      @provisioning_service.provision_vm(spec)
    end
  end

  def create_storage(spec)
    @queue << SpecTask.new(spec) do
      @provisioning_service.create_storage(spec)
    end
  end

  def archive_persistent_storage(spec, archive_datetime)
    @queue << SpecTask.new(spec) do
      @provisioning_service.archive_persistent_storage(spec, archive_datetime)
    end
  end

  def check_definition(spec, ignore_safe_vm_diffs)
    @queue << SpecTask.new(spec) do
      @provisioning_service.check_vm_definition(spec, ignore_safe_vm_diffs)
    end
  end

  def destroy(spec)
    return if !@virsh.is_defined(spec)
    @queue << SpecTask.new(spec) do
      @provisioning_service.clean_vm(spec)
    end
  end

  def allocate_ip(spec)
    @queue << SpecTask.new(spec) do
      @provisioning_service.allocate_ip(spec)
    end
  end

  def free_ip(spec)
    @queue << SpecTask.new(spec) do
      @provisioning_service.free_ip(spec)
    end
  end

  def process
    @logger.info("Process work queue")
    threads = []
    total = @queue.size
    @worker_count.times do|i|
      threads << Thread.new do
        while !@queue.empty?
          task = @queue.pop(true)
          task.spec[:thread_number] = i
          require 'yaml'
          error = nil
          begin
            msg = task.execute
          rescue Exception => e
            print e.backtrace
            @listener.error(task.spec, e)
            error = e
          ensure
            @listener.passed(task.spec, msg) if error.nil?
          end
        end
      end
    end
    threads.each(&:join)
  end
end
