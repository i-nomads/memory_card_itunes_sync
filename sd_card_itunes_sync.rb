# encoding: utf-8
require 'rubygems'
require 'bundler'
Bundler.require(:default)
require 'yaml'
require 'cgi'
require 'fileutils'

doc = File.open("/Users/clabesse/Dropbox/iTunes/iTunes\ Music\ Library.xml") { |f| Nokogiri::PList(f) }
to_sync = YAML.load_file("./playlists.yml")
base_dir = "#{Dir.pwd}/tmp_sync"

to_sync.each do |volume, playlists|
  puts "*** Getting ready to sync #{playlists.count} playlists to '#{volume}'…"

  tracks = {}
  track_ids = {}

  doc["Tracks"].each do |track_id, infos|
    next if infos["Location"].include?("https")
    track_ids[track_id.to_i] = infos["Persistent ID"]
    tracks[infos["Persistent ID"]] = CGI.unescape(infos["Location"].gsub("file://", ''))
  end

  playlists.each do |playlist|
    plist_location = "#{base_dir}/#{playlist}/"
    FileUtils.mkdir_p(plist_location)

    puts "*** Checking tracks to delete for '#{playlist}'"
    present_tracks = Dir.glob("#{plist_location}/*").map { |f| f.split("//").last.split(' - ').first }
    plist = doc["Playlists"].find { |p| p["Name"] == playlist }
    incoming_tracks = plist["Playlist Items"].map { |i| track_ids[i["Track ID"]] }.compact
    to_delete = present_tracks - incoming_tracks
    to_add = incoming_tracks - present_tracks

    puts "*** Remove #{to_delete.count} outdated tracks to '#{playlist}'"
    to_delete.each do |track|
      track_name = Dir.glob("#{plist_location}/#{track}*").first
      print "- Removing #{track_name.split('/').last}…"
      FileUtils.rm(track_name)
      print "done.\n"
    end

    puts "*** Adding #{to_add.count} new tracks to '#{playlist}'"

    to_add.each do |track|
      track_location = tracks[track].gsub("%20", ' ')
      track_name = track_location.split('/').last
      print "- Copying #{track_name}…"
      target = "#{plist_location}#{track} - #{track_name}"
      if File.exists?(target)
        print "exists already.\n"
      else
        FileUtils.cp(track_location, target)
        print "done.\n"
      end
    end

    puts "*** Syncing '#{playlist}' to SD card"
    `rsync --links #{base_dir}/#{playlist.gsub(' ', '\ ')}/* /Volumes/#{volume.gsub(' ', '\ ')}/#{playlist.gsub(' ', '\ ')}`
  end
end

puts "Done!"
