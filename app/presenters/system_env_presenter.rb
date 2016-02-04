class SystemEnvPresenter
  def initialize(service_bindings)
    @service_bindings = service_bindings
  end

  def system_env
    { 'VCAP_SERVICES' => service_binding_env_variables(service_bindings) }
  end

  private

  attr_reader :service_bindings

  def service_binding_env_variables(service_bindings)
    services_hash = {}
    service_bindings.each do |service_binding|
      service_name = service_binding_label(service_binding)
      services_hash[service_name] ||= []
      services_hash[service_name] << service_binding_env_values(service_binding)
    end
    services_hash
  end

  def service_binding_env_values(service_binding)
    {
      'credentials'      => service_binding.credentials,
      'syslog_drain_url' => service_binding.syslog_drain_url
    }.merge(service_instance_presenter(service_binding.service_instance))
  end

  def service_instance_presenter(service_instance)
    @presenter = if service_instance.is_gateway_service
                   ManagedPresenter.new(service_instance)
                 else
                   ProvidedPresenter.new(service_instance)
                 end
  end

  def service_binding_label(service_binding)
    service_instance_presenter(service_binding.service_instance).to_hash['label']
  end

  class ProvidedPresenter
    def initialize(service_instance)
      @service_instance = service_instance
    end

    def to_hash
      {
        'label' => 'user-provided',
        'name'  => @service_instance.name,
        'tags'  => @service_instance.tags
      }
    end
  end

  class ManagedPresenter
    def initialize(service_instance)
      @service_instance = service_instance
    end

    def to_hash
      {
        'label'    => @service_instance.service.label,
        'provider' => @service_instance.service.provider,
        'plan'     => @service_instance.service_plan.name,
        'name'     => @service_instance.name,
        'tags'     => @service_instance.merged_tags
      }
    end
  end
end
