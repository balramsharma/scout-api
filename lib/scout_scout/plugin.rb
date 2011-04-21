class ScoutScout::Plugin < Hashie::Mash
  attr_accessor :server

  def initialize(hash)
    if hash['descriptors'] && hash['descriptors']['descriptor']
      @descriptor_hash = hash['descriptors']['descriptor']
      hash.delete('descriptors')
    end
    super(hash)
  end

  # All metric for this plugin, including their name and last reported value
  #
  # @return [Array] An array of ScoutScout::Metric objects
  def metrics
    @metrics ||= @descriptor_hash.map { |d| decorate_with_server_and_plugin(ScoutScout::Metric.new(d)) }
  end

  def email_subscribers
    response = ScoutScout.get("/#{ScoutScout.account}/clients/#{server.id}/email_subscribers?plugin_id=#{id}")
    doc = Nokogiri::HTML(response.body)

    table = doc.css('table.list').first
    user_rows = table.css('tr')[1..-1] # skip first row, which is headings

    user_rows.map do |row|
      name_td, receiving_notifications_td = *row.css('td')

      name = name_td.content.gsub(/[\t\n]/, '')
      checked = receiving_notifications_td.css('input').attribute('checked')
      receiving_notifications = checked && checked.value == 'checked'
      Hashie::Mash.new :name => name, :receiving_notifications => receiving_notifications
    end
  end

  def triggers
    response = ScoutScout.get("/#{ScoutScout.account}/clients/#{server.id}/triggers.xml?plugin_id=#{id}")
    response['triggers'].map { |trigger| decorate_with_server_and_plugin(ScoutScout::Trigger.new(trigger)) }
  end

protected

  def decorate_with_server_and_plugin(hashie)
    hashie.server = self.server
    hashie.plugin = self
    hashie
  end

end
