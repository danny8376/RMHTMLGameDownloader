require 'faraday'
require 'nokogiri'
require 'json'
require 'fileutils'

require './lib/platforms'
require './lib/plugins'

class Downloader
  DEFAULT_DATA_FILES = [
    "ContainerProperties",

    "Actors",
    "Classes",
    "Skills",
    "Items",
    "Weapons",
    "Armors",
    "Enemies",
    "Troops",
    "States",
    "Animations",
    "Tilesets",
    "CommonEvents",
    "System",
    "MapInfos",
  ]

  SYSTEM_IMAGES = [
    "Balloon",
    "ButtonSet",
    "Damage",
    "GameOver",
    "Loading",
    "IconSet",
    "Shadow1",
    "Shadow2",
    "States",
    "Weapons1",
    "Weapons2",
    "Weapons3",
    "Window",
  ]

  def initialize(game_url, output_dir)
    @game_url = game_url
    @output_dir = output_dir
    @platform = Platforms.init_platform game_url
    @non_exist = []
    @database = {}
    @plugins = []
  end

  def check_dir(path, file=false)
    dir = file ? File.dirname(path) : path
    FileUtils.mkdir_p dir unless File.exist? dir
  end

  def write(path, cont)
    fn = "#{@output_dir}/#{path}"
    check_dir fn, true
    File.write(fn, cont)
  end

  def dl(path, skip_exist=false)
    if @non_exist.include? path
      puts "File #{path} not exist, skip."
      return
    end
    if skip_exist and File.exist? "#{@output_dir}/#{path}"
      puts "File #{path} downloaded."
      return
    end
    puts "Downloading #{path} ..."
    cont = @platform.get path
    write path, cont
    cont
  rescue Exception => err
    case err.message
    when /^Err HTTP 404/
      @non_exist.push path
    else
      puts err.message
      for line in err.backtrace
        puts line
      end
    end
    nil
  end

  def dl_img(type, name)
    #return if name.nil? or name.empty?
    return if name.empty?
    dl "img/#{type}/#{name}.png", true
  end

  def dl_audio(type, name)
    #return if name.nil? or name.empty?
    return if name.empty?
    dl "audio/#{type}/#{name}.ogg", true
    dl "audio/#{type}/#{name}.m4a", true
  end

  def dl_movie(name)
    #return if name.nil? or name.empty?
    return if name.empty?
    dl "movies/#{name}.webm", true
    dl "movies/#{name}.mp4", true
  end

  def process_event_list(list)
    buffer = Struct.new(:next_codes, :cont, :proc).new([], "", nil)
    for cmd in list
      code = cmd['code']

      # process previous buffered command
      if not buffer.next_codes.empty? and not buffer.next_codes.include?(code)
        buffer.proc.call buffer.cont
        buffer.next_codes.clear
        buffer.cont = ""
        buffer.proc = nil
      end

      case code
      when 101 # Show Text
        dl_img "faces", cmd['parameters'][0]
      when 132, 140 # Change Battle/Vehicle BGM
        dl_audio "bgm", cmd['parameters'][0]['name']
      when 133, 139 # Change Victory/Defeat ME
        dl_audio "me", cmd['parameters'][0]['name']
      when 205 # Set Movement Route
        process_move_list cmd['parameters'][1]['list']
      when 231 # Show Picture
        dl_img "pictures", cmd['parameters'][1]
      when 241 # Play BGM
        dl_audio "bgm", cmd['parameters'][0]['name']
      when 245 # Play BGS
        dl_audio "bgs", cmd['parameters'][0]['name']
      when 249 # Play ME
        dl_audio "me", cmd['parameters'][0]['name']
      when 250 # Play SE
        dl_audio "se", cmd['parameters'][0]['name']
      when 261 # Play Movie
        dl_movie cmd['parameters'][0]
      when 283 # Change Battle Back
        dl_img "battlebacks1", cmd['parameters'][0]
        dl_img "battlebacks2", cmd['parameters'][1]
      when 284 # Change Parallax
        dl_img "parallaxes", cmd['parameters'][0]
      when 322 # Change Actor Images
        dl_img "characters", cmd['parameters'][1]
        dl_img "faces", cmd['parameters'][3]
        dl_img "sv_actors", cmd['parameters'][5] # side battle only
      when 323 # Change Vehicle Image
        dl_img "characters", cmd['parameters'][1]
      when 355 # Script
        buffer.next_codes.push 655 # script line
        buffer.cont = "#{cmd['parameters'][0]}\n"
        buffer.proc = Proc.new do |script|
          process_script script
        end
      when 655 # Script Line
        buffer.cont += "#{cmd['parameters'][0]}\n"
      when 356 # Plugin Command
        pargs = cmd['parameters'][0].split " "
        pcmd = pargs.shift
        process_plugin pcmd, pargs
      end
    end
  end

  def process_move_list(list)
    for cmd in list
      case cmd['code']
      when 41 # ROUTE_CHANGE_IMAGE
        dl_img "characters", cmd['parameters'][0]
      when 44 # ROUTE_PLAY_SE
        dl_audio "se", cmd['parameters'][0]['name']
      when 45 # ROUTE_SCRIPT
        process_script cmd['parameters'][0]
      end
    end
  end

  def process_map(map_id)
    mapfile = "data/Map#{map_id.to_s.rjust(3, "0")}.json"
    puts "Getting #{mapfile}"
    mapcont = dl mapfile
    data = JSON.parse(mapcont)
    dl_img "battlebacks1", data['battleback1Name']
    dl_img "battlebacks2", data['battleback2Name']
    dl_img "parallaxes", data['parallaxName']
    dl_audio "bgm", data['bgm']['name']
    dl_audio "bgs", data['bgs']['name']
    evts = data['events']
    evts.shift # remove first as rm starts at 1
    evts.pop if evts[-1].nil?
    for evt in evts
      for page in evt['pages']
        dl_img "characters", page['image']['characterName']
        process_event_list page['list']
        process_move_list page['moveRoute']['list']
      end
    end
  end

  def process_script(script)
  end

  def process_plugin(cmd, args)
  end

  def process_data
    for dataname in DEFAULT_DATA_FILES
      datafile = "data/#{dataname}.json"
      puts "Getting #{datafile}"
      begin
        datacont = dl datafile
        next if datacont.nil?
        data = @database[dataname] = JSON.parse(datacont)
        if respond_to? "process_data_#{dataname.downcase}"
          puts "Processing #{dataname}"
          send "process_data_#{dataname.downcase}", data
        end
      rescue Exception => err
        puts err.message
        for line in err.backtrace
          puts line
        end
      end
    end
  end

  def process_data_actors(data)
    data.shift # remove first as rm starts at 1
    data.pop if data[-1].nil?
    for ch in data
      dl_img "faces", ch['faceName']
      dl_img "sv_actors", ch['battlerName'] # side battle only
      dl_img "characters", ch['characterName']
    end
  end

  def process_data_enemies(data)
    data.shift # remove first as rm starts at 1
    data.pop if data[-1].nil?
    for enemy in data
      dl_img "enemies", enemy['battlerName']
      dl_img "sv_enemies", enemy['battlerName'] # side battle only
    end
  end

  def process_data_animations(data)
    data.shift # remove first as rm starts at 1
    data.pop if data[-1].nil?
    for ani in data
      dl_img "animations", ani['animation1Name']
      dl_img "animations", ani['animation2Name']
      for timing in ani['timings']
        dl_audio "se", timing['se']['name'] if timing['se']
      end
    end
  end

  def process_data_tilesets(data)
    data.shift # remove first as rm starts at 1
    data.pop if data[-1].nil?
    for tileset in data
      for name in tileset['tilesetNames']
        dl_img "tilesets", name
      end
    end
  end

  def process_data_commonevents(data)
    data.shift # remove first as rm starts at 1
    data.pop if data[-1].nil?
    for cevt in data
      process_event_list cevt['list']
    end
  end

  def process_data_system(data)
    dl_img "characters", data['airship']['characterName']
    dl_audio "bgm", data['airship']['bgm']['name']
    dl_img "characters", data['boat']['characterName']
    dl_audio "bgm", data['boat']['bgm']['name']
    dl_img "characters", data['ship']['characterName']
    dl_audio "bgm", data['ship']['bgm']['name']
    dl_img "battlebacks1", data['battleback1Name']
    dl_img "battlebacks2", data['battleback2Name']
    #dl_img "???", data['battlerName'] # test data?
    dl_img "titles1", data['title1Name']
    dl_img "titles2", data['title2Name']
    dl_audio "bgm", data['titleBgm']['name']
    dl_audio "bgm", data['battleBgm']['name']
    dl_audio "me", data['defeatMe']['name']
    dl_audio "me", data['gameoverMe']['name']
    dl_audio "me", data['victoryMe']['name']
    for sound in data['sounds']
      dl_audio "se", sound['name']
    end
  end

  def process_data_mapinfos(data)
    data.shift # remove first as rm starts at 1
    data.pop if data[-1].nil?
    for map in data
      process_map map['id']
    end
  end

  def process_plugins
    for plugin in @plugins
      name = plugin['name']
      fn = "js/plugins/#{name}.js"
      cont = dl fn
      if plugin['status']
        Plugins.process_plugin(name, cont, plugin['parameters'], @database) do |cmd, *args|
          if cmd.start_with? "dl"
            send cmd, *args
          end
        end
      end
    end
  end

  def process_system_images
    for img in SYSTEM_IMAGES
      dl_img "system", img
    end
  end

  def run
    puts "Getting index.html"
    index = @platform.index

    # Download icons
    for ele in index.css("head link[rel*=icon]")
      dl ele['href'], true
    end
    # Download CSS
    for ele in index.css("head link[rel~=stylesheet]")
      path = ele['href']
      base = File.dirname path
      cont = dl path
      matches = cont.scan /url\("?([^"]*)"?\)/
      for match in matches
        # assume all relative path
        dl "#{base}/#{match[0]}", true
      end
    end

    @platform.process_index_scripts do |src|
      cont = dl src
      case src
      when "js/plugins.js"
        @plugins = JSON.parse cont.match(/\$plugins\s*=\s*(\[.*\]);?/m)[1]
      end
    end

    write("index.html", index.to_html) # save index.html

    process_data
    process_plugins
    process_system_images
    
    puts "All Done!"
  end
end

