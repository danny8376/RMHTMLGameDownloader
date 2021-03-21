module Platforms
  PLATFORM_LIST = []

  def self.init_platform(url)
    for platform_class in PLATFORM_LIST
      platform = platform_class.match url
      return platform if platform
    end
    raise "Not supported platform!"
  end
end

require './lib/platforms/nico'
require './lib/platforms/freem'

