class ScoutScout::Server < Hashie::Mash
  def initialize(hash)
    if hash['active_alerts']
      @alert_hash = hash['active_alerts']
      hash.delete('active_alerts')
    end
    super(hash)
  end

  # Search for a server by id or matching hostname
  #
  # @return [ScoutScout::Server]
  def self.first(server_id_or_hostname)
    if server_id_or_hostname.is_a?(Fixnum)
      response = ScoutScout.get("/#{ScoutScout.account}/clients/#{server_id_or_hostname}.xml")
      ScoutScout::Server.new(response['client'])
    else
      response = ScoutScout.get("/#{ScoutScout.account}/clients.xml?host=#{server_id_or_hostname}")
      raise ScoutScout::Error, 'Not Found' if response['clients'].nil?
      ScoutScout::Server.new(response['clients'].first)
    end
  end
  
  # Creates a new server. If an error occurs, a +ScoutScout::Error+ is raised.
  #
  # An optional existing server id can be used as a template:
  # ScoutScout::Server.create('web server 12',:id => 99999)
  #
  # @return [ScoutScout::Server]
  def self.create(name,options = {})
    id = options[:id]
    response = ScoutScout.post("/#{ScoutScout.account}/clients.xml", 
    :query => {:client => {:name => name, :copy_plugins_from_client_id => id}})
    
    raise ScoutScout::Error, response['errors']['error'] if response['errors']
    
    first(response.headers['id'].first.to_i)
  end
  
  # Delete a server by id. If an error occurs, a +ScoutScout::Error+ is raised.
  #
  # @return [true]
  def self.delete(id)
    response = ScoutScout.delete("/#{ScoutScout.account}/clients/#{id}.xml")

    if response.headers['status'].first.match('404')
      raise ScoutScout::Error, "Server Not Found"
    elsif !response.headers['status'].first.match('200')
      raise ScoutScout::Error, "An error occured"
    else
      return true
    end
  end

  # Search for servers by matching hostname via :host.
  #
  # Example: ScoutScout::Server.all(:host => 'soawesome.org')
  #
  # @return [Array] An array of ScoutScout::Server objects
  def self.all(options)
    hostname = options[:host]
    raise ScoutScout::Error, "Please specify a host via :host" if hostname.nil?
    response = ScoutScout.get("/#{ScoutScout.account}/clients.xml?host=#{hostname}")
    response['clients'] ? response['clients'].map { |client| ScoutScout::Server.new(client) } : Array.new
  end

  # Active alerts for this server
  #
  # @return [Array] An array of ScoutScout::Alert objects
  def active_alerts
    @active_alerts ||= @alert_hash.map { |a| decorate_with_server(ScoutScout::Alert.new(a)) }
  end

  # Recent alerts for this server
  #
  # @return [Array] An array of ScoutScout::Alert objects
  def alerts
    response = ScoutScout.get("/#{ScoutScout.account}/clients/#{self.id}/activities.xml")
    response['alerts'].map { |alert| decorate_with_server(ScoutScout::Alert.new(alert)) }
  end

  # Details about all plugins for this server
  #
  # @return [Array] An array of ScoutScout::Plugin objects
  def plugins
    response = ScoutScout.get("/#{ScoutScout.account}/clients/#{self.id}/plugins.xml")
    response['plugins'].map { |plugin| decorate_with_server(ScoutScout::Plugin.new(plugin)) }
  end

  # Details about a specific plugin
  #
  # @return [ScoutScout::Plugin]
  def plugin(id)
    response = ScoutScout.get("/#{ScoutScout.account}/clients/#{self.id}/plugins/#{id}.xml")
    decorate_with_server(ScoutScout::Plugin.new(response['plugin']))
  end

  # All descriptors for this server
  #
  # @return [Array] An array of ScoutScout::Descriptor objects
  def descriptors
    ScoutScout::Descriptor.all(:host => hostname).map { |d| decorate_with_server(d) }
  end

  # Details about all triggers for this server
  #
  # @return [Array] An array of ScoutScout::Trigger objects
  def triggers
    response = ScoutScout.get("/#{ScoutScout.account}/clients/#{self.id}/triggers.xml")
    response['triggers'].map { |trigger| decorate_with_server(ScoutScout::Trigger.new(trigger)) }
  end

protected

  def decorate_with_server(hashie)
    hashie.server = self
    hashie
  end

end