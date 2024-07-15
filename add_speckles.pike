//Add some random black and white pixels to an image
int main(int argc, array(string) argv) {
	if (argc < 3) exit(1, "USAGE: pike %s filename.png num_pixels\nEdits image in place.", argv[0]);
	Image.Image img = Image.PNG.decode(Stdio.read_file(argv[1]));
	array border = img->find_autocrop();
	//Crop off 80% of the border
	border[0] = border[0] * 8 / 10;
	border[1] = border[1] * 8 / 10;
	border[2] = img->xsize() - (img->xsize() - border[2]) * 8 / 10;
	border[3] = img->xsize() - (img->xsize() - border[3]) * 8 / 10;
	write("Crop: %O\n", border);
	img = img->copy(@border);
	int speckles = (int)argv[2];
	while (speckles-- > 0) {
		int x = random(img->xsize()), y = random(img->ysize());
		//Assume the image is greyscale and just look at the red channel
		if (img->getpixel(x, y)[0] > 128) img->setpixel(x, y, 0, 0, 0); //If white (or pale), make black
		else img->setpixel(x, y, 255, 255, 255); //Else whiten.
	}
	Stdio.write_file(argv[1], Image.PNG.encode(img));
}
