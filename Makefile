all: Nightmare.hocr Grotty.png

Nightmare.hocr: Nightmare.png
	tesseract Nightmare.png Nightmare hocr

Nightmare.png: Nightmare.pdf
	convert -density 300 Nightmare.pdf -background white -alpha remove Nightmare.png

Nightmare.pdf: Nightmare.md
	pandoc Nightmare.md -tpdf -oNightmare.pdf -Vgeometry:margin=20mm --pdf-engine=lualatex

Grotty.png: Nightmare.pdf add_speckles.pike
	convert -density 150 Nightmare.pdf -background white -alpha remove Grotty.png
	pike add_speckles Grotty.png 2000
