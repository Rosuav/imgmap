Nightmare.pdf: Nightmare.md
	pandoc Nightmare.md -tpdf -oNightmare.pdf -Vgeometry:margin=20mm --pdf-engine=lualatex
