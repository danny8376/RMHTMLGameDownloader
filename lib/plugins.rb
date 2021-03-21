module Plugins
  PLUGIN_LIST = []

  def self.process_plugin(*args, &block)
    for plugin_class in PLUGIN_LIST
      plugin = plugin_class.match *args, &block
      return plugin if plugin
    end
    return nil
  end
end

require './lib/plugins/plugin_org_DekoMain'
