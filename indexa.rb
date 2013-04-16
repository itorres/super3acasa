#!/usr/bin/env ruby
require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'yaml'

$conf = YAML.load(File.open('config.yaml'))

def list_chapters
  dades_extraure = ['id', 'capitol', 'durada_segs', 'title', 'data', 'file', 'promo']
  Dir.foreach($conf[:download_dir]) { | file |
  	dades_episodi = Hash.new
	ext=File.extname(file)
	programid=File.basename(file,ext)
	videofile="#{$conf[:download_dir]}/#{programid}.mp4"
	metafile="#{$conf[:download_dir]}/#{programid}.xml"
	next if ext != '.xml'
	next if File.size?(videofile) == nil
	@doc = Nokogiri::XML(open(metafile))
	@doc.css("item").each() do |item|
		dades_extraure.each do |dada|
			dades_episodi[dada] = item.css(dada).text().strip
		end
	end
	target_dir = File.join($conf[:index_dir],dades_episodi['promo'])
	Dir.mkdir(target_dir) if not Dir.exists?(target_dir)
	targetname="#{dades_episodi['title']}.mp4".gsub('/','-')
	linkfile = File.join(target_dir,targetname)
	if not File.exists?(linkfile)
		File.link(videofile,linkfile)
		puts(linkfile)
	end
  }
end
list_chapters()
