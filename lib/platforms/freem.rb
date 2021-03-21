require 'faraday_middleware'

module Platforms
  class Freem
    URL_MATCH = /^https?:\/\/www\.freem\.ne\.jp\/win\/game\/(\d+)/

    GAME_LINK_MATCH = /^\s*(?:var|let|const)\s*dlLinkUrl\s*=\s*"(?<gamestarturl>[^"]+)";?/
    INFO_HOST = "https://www.freem.ne.jp"

    def initialize(url)
      @url = url
      @conn = Faraday.new do |faraday|
        faraday.response :follow_redirects
      end
      retrive_game_link
    end

    def retrive_game_link
      info = @conn.get @url
      @game_start_url = "#{INFO_HOST}#{info.body.match(GAME_LINK_MATCH)['gamestarturl']}"
      start_page = Nokogiri::HTML @conn.get(@game_start_url).body
      start_info = start_page.css("script[data-game-id][data-hostname][data-session]")[0]
      game_id = start_info['data-game-id']
      hostname = start_info['data-hostname']
      session = start_info['data-session']
      # From https://lib.fplay.xyz/js/happy_browser_game.js
      @index_url = "https://#{game_id}.#{hostname}/play/game/#{game_id}/#{session}"
    end

    def base_url
      return @base_url
    end

    def get(path)
      res = @conn.get "#{base_url}#{path}"
      raise "Err HTTP #{res.status}, path #{path}, content: #{res.body}" unless res.status == 200 and not res.body.empty?
      return res.body
    end

    def index
      @index = Nokogiri::HTML @conn.get(@index_url).body unless @index
      base_ele = @index.css("base")[0]
      @base_url = base_ele['href']
      base_ele.remove
      @base_url = "https:#{@base_url}" if @base_url.start_with? "//"
      @index.css("link[rel=stylesheet][href^=\"//\"]").each(&:remove)
      @index
    end

    def process_index_scripts
      for ele in @index.css("script")
        yield ele['src'] # pass file
      end
    end

    def self.match(url)
      return self.new url if URL_MATCH =~ url
    end
  end

  PLATFORM_LIST.push Freem
end

