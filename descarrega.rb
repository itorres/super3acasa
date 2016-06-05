#!/usr/bin/env ruby
# encoding: utf-8
require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'yaml'


def llista_programes()
	llista = Array.new
	dades_extraure = ['category', 'titol']
	@doc = Nokogiri::XML(open('http://www.super3.cat/feeds/programes/seriesSuper3.jsp?format=xml&amp;device=iphone&amp;pagina=0&amp;itemsPagina=60'))
	@doc.css("item").each() do |item|
		llista.push(item.css('category')[0].text().strip)
	end
	return llista
end


def ollista_programes()
	Net::HTTP.start("www.super3.cat") do | http |
		resp = http.get("/feeds/programes/seriesSuper3.jsp?format=xml&amp;device=iphone&amp;pagina=0&amp;itemsPagina=20")
		programes_xml=resp.body
	end
	return llista
end

def llista_episodis(codiserie)
	llista = Array.new
	@doc = Nokogiri::XML(open("http://www.super3.cat/searcher/super3/searching.jsp?format=MP4&catBusca=#{codiserie}&presentacion=xml&pagina=1&itemsPagina=20"))
	@doc.css("item").each() do |item|
		# printf("=== %-4s: %s\n", item['idint'],item.css('titol').text().strip)
		#puts item
		llista.push(item['idint'])
		#puts llista
	end
	return llista
end

def descarrega_dades_episodi(programid)
	dades_episodi = Hash.new
	dades_extraure = ['id', 'capitol', 'durada_segs', 'title', 'data', 'file', 'promo']
begin
	@doc = Nokogiri::XML(open("http://www.tv3.cat/pvideo/FLV_bbd_dadesItem_MP4.jsp?idint=#{programid}"))
	@doc.css("item").each() do |item|
		dades_extraure.each do |dada|
			dades_episodi[dada] = item.css(dada).text().strip
		end
		item.xpath('.//video[file]').each() do |video|
			format = video.css('format').text.strip()
			if format == 'MP4'
				dades_episodi['file'] = video.css('file').text.strip()
			else
				dades_episodi["file-#{format}"] = video.css('file').text.strip()
			end
		end
		dades_episodi['q'] = item.css('file').attr('quality').text()
		dades_episodi['xml'] = @doc.to_xml
	end
	infofile = File.join($conf[:download_dir], "#{programid}.xml")
	open(infofile, "w") { |f| @doc.write_xml_to f }
	descarrega_episodi(dades_episodi)
rescue Exception => e
    puts "  !! Unhandled exception in descarrega_dades: #{programid} "
    raise e
end
end

def tengui(programid)
	videofile = File.join($conf[:download_dir], "#{programid}.mp4")
	if File.size?(videofile) == nil
		return false
	else
		return true
	end
end

def descarrega_episodi(dades_episodi)
	url = "/pvideo/FLV_bbd_dadesItem_MP4.jsp?idint=#{dades_episodi['id']}"
	videofile = File.join($conf[:download_dir], "#{dades_episodi['id']}.mp4")
	puts "  > Descarregant #{dades_episodi['title']}"
	begin
		File.open(videofile, 'wb') do |saved_file|
			open(dades_episodi['file'], 'rb') do |read_file|
				saved_file.write(read_file.read)
			end
			puts "  + Descarregat #{videofile}  #{dades_episodi['promo']} #{dades_episodi['title']}"
		end if not tengui(dades_episodi['id'])
	rescue OpenURI::HTTPError => http_error
		puts YAML.dump(http_error)
		puts  dades_episodi['xml']
		raise
	end
end

puts "#{Time.now()} Començant sessió de descarrega"
puts "  Arguments: " << YAML.dump(ARGV)

puts ARGV.length
if (ARGV.length > 0 && ARGV[0] == "-c")
	ARGV.shift
	conf_file = ARGV.shift
else
	conf_file = 'config.yaml'
end
$conf = YAML.load(File.open(conf_file))
STDOUT.flush
if (ARGV.length == 0)
	puts "LLista de programes"
	llista_programes().each() do |codiserie|
		puts " Serie: #{codiserie}"
		STDOUT.flush
		llista_episodis(codiserie).each() do |programid|
			puts "  Programa: #{programid}"
			descarrega_dades_episodi(programid) if not tengui(programid)
			STDOUT.flush
		end
	end
else
	what=ARGV.shift
	if what == "-s"
		serie = ARGV.shift
		episodis = llista_episodis(serie)
		puts YAML.dump(episodis)
		puts " Serie: #{serie}"
		episodis.each() do |programid|
			puts "  Programa: #{programid}"
			descarrega_dades_episodi(programid) if not tengui(programid)
		end
	elsif what =="-f"
		programid = ARGV.shift
		descarrega_dades_episodi(programid) if not tengui(programid)
	end
end
puts "#{Time.now()} Finalitzada sessió de descarrega"
