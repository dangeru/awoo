from PIL import Image, ImageDraw, ImageFont
import random, string
wordlist = "/usr/share/dict/american-english"
wordlist = open(wordlist).read().split("\n")
while True:
	word = random.choice(wordlist)
	word2 = random.choice(wordlist)
	letters = "".join(random.sample(string.ascii_letters, 10))
	out = Image.new('RGBA', (282, 26), (0, 0, 0, 255))
	d = ImageDraw.Draw(out)
	d.text((random.randint(5, 200), random.randint(0, 14)), word, fill=(255, 255, 255, 255))
	d.text((random.randint(5, 200), random.randint(0, 14)), letters, fill=(255, 45, 45, 150))
	d.text((random.randint(5, 200), random.randint(0, 14)), word2, fill=(126, 255, 126, 255))
	filename = word + letters + word2 + ".png"
	out.save(filename)
	print("written to " + filename)
