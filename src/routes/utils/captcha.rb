require 'mini_magick'
# this is not recommended
Encoding.default_internal = Encoding::UTF_8
Encoding.default_external = Encoding::UTF_8
#Fonts = %x[convert -list font].split("\n")
Fonts = %w(ZXX-Camo ZXX-Noise ZXX-Xed)
#Fonts.select! do |f| f.strip.split[0] == "Font:" end.map! do |f| f.strip.split[1] end
Wordlist = "/usr/share/dict/words"
Words = File.read(Wordlist).split("\n").select! do |w| !w.include?("'") && w.length <= 5 && w.length >= 3 end.map! do |w| w.downcase end
def make_text
	rr = ->() do
		127 + Random.rand(127);
	end
	text = "#{Words.sample} #{Words.sample} #{Words.sample}"
	font = Fonts.sample
	filename = "/dev/shm/"
	text.each_codepoint do |x|
		if x >= 97 && x <= 122
			filename += x.chr
		end
	end
	filename += ".png"
	MiniMagick::Tool::Convert.new do |img|
		img.size "450x60"
		img << "xc:black"
		img.fill "rgb(#{rr.call}, #{rr.call}, #{rr.call})"
		img.stroke "rgb(#{rr.call}, #{rr.call}, #{rr.call})"
		img.pointsize "40"
		img.gravity "center"
		img.font font
		img.draw "text 0,0 '#{text}'"
		img << filename
	end
	bytes = File.read filename
	File.delete filename
	return [text, bytes]
end
