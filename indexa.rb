#!/usr/bin/env ruby
# encoding: UTF-8
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
	begin
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
	rescue => e
		puts Time.new.inspect << " #{e.class} exception parsing " << File.join($conf[:download_dir], file )
		puts e.inspect
		puts e.backtrace
	end

	begin
		target_dir = File.join($conf[:index_dir],dades_episodi['promo'])
		Dir.mkdir(target_dir) if not Dir.exists?(target_dir)
		targetname="#{dades_episodi['title']}.mp4".gsub(/[\/:]/,'-')
		linkfile = File.join(target_dir,targetname)
		# puts Time.new.inspect << " Trying to index " << linkfile
		if not File.exists?(linkfile)
			File.link(videofile,linkfile)
			puts("Indexing " << linkfile)
		end
	rescue => e
		puts Time.new.inspect << " #{e.class} exception indexing " << File.join($conf[:download_dir], file )
		puts e.inspect
		puts e.backtrace
	end

	begin
		if $conf[:publish].has_key?(dades_episodi['promo'])
			if $conf[:publish][dades_episodi['promo']] == nil
				promo_dir = dades_episodi['promo']
			else
				promo_dir = $conf[:publish][dades_episodi['promo']]
			end
			publish_dir = File.join($conf[:publish_dir], promo_dir)
			Dir.mkdir(publish_dir) if not Dir.exists?(publish_dir)
			targetname="#{dades_episodi['title']}.mp4".gsub(/[:\/]/,'-')
			linkfile = File.join(publish_dir,targetname)
			# puts Time.new.inspect << " Trying to publish " << linkfile
			if not File.exists?(linkfile)
				File.link(videofile,linkfile)
				puts("Publishing" << linkfile)
			end
		end
	rescue => e
		puts Time.new.inspect << " #{e.class} exception publishing " << File.join($conf[:download_dir], file )
		puts e.inspect
		puts e.backtrace
	end

  }
end
puts "#{Time.now()} Començant sessió d'indexació"
list_chapters()
puts "#{Time.now()} Finalitzada sessió d'indexació"
