#!/usr/bin/env ruby
require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'yaml'

if (ARGV.length > 0 && ARGV[0] == "-c")
	ARGV.shift
	conf_file = ARGV.shift
else
	conf_file = 'config.yaml'
end
$conf = YAML.load(File.open(conf_file))

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
		puts("Indexing " << linkfile)
	end

	if $conf[:publish].has_key?(dades_episodi['promo'])
		if $conf[:publish][dades_episodi['promo']] == nil
			promo_dir = dades_episodi['promo']
		else
			promo_dir = $conf[:publish][dades_episodi['promo']]
		end
		publish_dir = File.join($conf[:publish_dir], promo_dir)
		Dir.mkdir(publish_dir) if not Dir.exists?(publish_dir)
		targetname="#{dades_episodi['title']}.mp4".gsub('/','-')
		linkfile = File.join(publish_dir,targetname)
		if not File.exists?(linkfile)
			File.link(videofile,linkfile)
			puts("Publishing" << linkfile)
		end
	end

  }
end
list_chapters()
