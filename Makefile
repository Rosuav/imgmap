Nightmare.png: Nightmare.pdf
	convert -density 300 Nightmare.pdf -background white -alpha remove Nightmare.png

Nightmare.pdf: Nightmare.md
	pandoc Nightmare.md -tpdf -oNightmare.pdf -Vgeometry:margin=20mm --pdf-engine=lualatex
