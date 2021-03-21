#!/usr/bin/env ruby

require './lib/downloader'



require 'pp'

# TEST ONLY
#game_url = "https://game.nicovideo.jp/atsumaru/games/gm18811"
game_url = "https://www.freem.ne.jp/win/game/25118"
output_dir = "output_test"



dl = Downloader.new game_url, output_dir
dl.run

