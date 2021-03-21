require 'securerandom'
require 'faraday_middleware'

module Platforms
  class Nico
    URL_MATCH = /^https?:\/\/game\.nicovideo\.jp\/atsumaru\/games\/(gm\d+)/

    API_HOST = "https://api.game.nicovideo.jp"
    GAME_HOST = "https://html5.nicogame.jp"

    def initialize(url)
      @id = url.match(URL_MATCH)[1]
      @game_conn = Faraday.new do |faraday|
        faraday.response :follow_redirects
      end
    end

    def ticket_url
      "#{API_HOST}/v1/rpgtkool/games/#{@id}/play-tickets.json?wipAccessKey"
    end

    def base_url
      #"https://html5.nicogame.jp/games/#{@id}/#{@version}/"
      return @base_url
    end

    def request_ticket
      boundary = "--------#{SecureRandom.uuid}"
      res = Faraday.post(ticket_url, "--#{boundary}--\r\n", {
        'Content-Type': "multipart/form-data; boundary=#{boundary}",
        'X-Request-With': "https://game.nicovideo.jp"
      })
      game = JSON.parse(res.body)["data"]
      @exires = Time.at(game["expires"])
      @ticket = game["playTicket"]
      @sig = game["signature"]
      @base_url = "#{GAME_HOST}#{game["path"]}/"
    end

    def check_ticket
      @ticket and @expires and @expires < Time.now
    end

    def ticket_cookie
      request_ticket unless check_ticket
      "playticket2=#{@ticket}; playticket2_signature=#{@sig}"
    end

    def get(path)
      cookie = ticket_cookie # must at seperate line (path is generated by result of ticket data)
      res = @game_conn.get "#{base_url}#{path}" do |req|
        req.headers['Cookie'] = cookie
      end
      raise "Err HTTP #{res.status}, path #{path}, content: #{res.body}" unless res.status == 200 and not res.body.empty?
      return res.body
    end

    def process_index_scripts(index_dom)
      for ele in index_dom.css("script")
        src = ele['src']
        if src.start_with? "/"
          #remove all script outside game path (NicoNico specific)
          ele.remove
        else
          yield src # pass file
        end
      end
    end

    def self.match(url)
      return self.new url if URL_MATCH =~ url
    end
  end

  PLATFORM_LIST.push Nico
end
