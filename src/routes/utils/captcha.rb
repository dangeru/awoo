require 'mini_magick'
# this is not recommended
Encoding.default_internal = Encoding::UTF_8
Encoding.default_external = Encoding::UTF_8
Wordlist = "/usr/share/dict/words"
Words = File.read(Wordlist).split("\n").select! do |w| !w.include?("'") && w.length <= 5 && w.length >= 3 end.map! do |w| w.downcase end
Memes = ["REOL", "danger/u/", "poi", "burg", "nano", "dorothy", "awoo", "bad touch", "brandtini", "bronson extract", "karmotrine"]
def make_text
	rr = ->() do
		127 + Random.rand(127);
	end
	word = -> () do
		Random.rand(4) != 0 ? Words.sample : Memes.sample
	end
	text = "#{word.call} #{word.call} #{word.call}"
	realtext = ""
	text.each_codepoint do |x|
		# keep only ascii lowercase letters and spaces
		# sometimes something comes along with an é or ñ or something and
		# it shows up as a question mark in the zxx font, and nobody can type the captcha
		if (x >= 97 && x <= 122) || x == 0x20
			realtext += x.chr
		end
	end
	filename = "/dev/shm/#{realtext}.png"
	MiniMagick::Tool::Convert.new do |img|
		img.size "450x90"
		img << "xc:black"
		img.bordercolor "black" # ??
		img.border "5" # ??
		color = "rgb(#{rr.call}, #{rr.call}, #{rr.call})"
		img.fill color
		img.stroke color
		img.strokewidth "1"
		img.font "TimesNewRoman"
		img.pointsize "40"
		xs = []
		ys = []
		x = -450/2
		realtext.each_codepoint do |c|
			x = x + (450 / (realtext.length + 1)) + Random.rand(20) - 10
			y = Random.rand(20) - 10
			xs << x * 1.1 + (450 / 2)
			ys << y * 2 + (90 / 2)
			img.draw "translate #{x},#{y} rotate #{Random.rand(20) - 10} skewX #{Random.rand(35) - (35/2)} gravity center text 0,0 '#{c.chr}'"
		end
		img.fill "none"
		img.strokewidth "4"
		img.draw "bezier #{xs.zip(ys).flatten[0..15].join(",")}"
		img.draw "polyline #{xs.zip(ys).flatten[14..-1].join(",")}"
		img << filename
	end
	bytes = File.read filename
	File.delete filename
	return [text, bytes]
end
