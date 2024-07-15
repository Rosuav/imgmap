array list_words(string xml) {
	return Parser.XML.Simple()->parse(xml) {
		[string type, string name, mapping(string:string) attr, mixed data, mixed loc] = __ARGS__;
		switch(type) {
			case "": data = String.trim(data); return data != "" && data;
			case "<>": case ">":
				if (arrayp(data) && sizeof(data) == 1 && stringp(data[0])) {
					//Parse out the bounding box (eg "bbox 100 100 400 200")
					array pos;
					foreach (attr->title / "; ", string thing)
						if (has_prefix(thing, "bbox ")) pos = (array(int))(thing / " ")[1..];
					return (["text": data[0], "pos": pos]);
				}
				if (arrayp(data)) return Array.arrayify(data[*]) * ({ });
				return data;
			default: return 0;
		}
	}[0];
}

array match_arrays(array arr1, array arr2, function pred) {
	//Step through the arrays, finding those that match
	//The predicate function should return a truthy value when they match, and these values
	//will be collected into the result.
	int d1, d2; //Denoters for the respective arrays
	array ret = ({ });
	nextmatch: while (d1 < sizeof(arr1) && d2 < sizeof(arr2)) {
		if (mixed match = pred(arr1[d1], arr2[d2])) {
			//Match!
			d1++; d2++;
			ret += ({match});
			continue;
		}
		//Try to advance d1 until we get a match; not too many steps though.
		//The limit is a tweakable - if resynchronization can happen after
		//that many failures, it might be a phantom resync and not actually
		//helpful. A lower number is also faster than a higher one.
		for (int i = 1; i < 10 && d1 + i < sizeof(arr1); ++i) {
			if (mixed match = pred(arr1[d1+i], arr2[d2])) {
				//That'll do!
				d1 += i + 1; d2++;
				ret += ({match});
				continue nextmatch;
			}
		}
		//No match in the next few? Skip one from arr2 and carry on.
		d2++;
	}
	return ret;
}

array centroid(array pos) {
	return ({(pos[0] + pos[2]) / 2, (pos[1] + pos[3]) / 2});
}

array xfrm(array matrix, int x, int y) {
	//No easy matmul operation, so we do it manually
	return ({matrix[0] * x + matrix[1] * y + matrix[2],
		 matrix[3] * x + matrix[4] * y + matrix[5]});
}

int main() {
	array original = list_words(utf8_to_string(Stdio.read_file("Nightmare.hocr")));
	object pythonstdin = Stdio.File(), pythonstdout = Stdio.File();
	string pythonbuf = "";
	object python = Process.create_process(({"python3.12", "regress.py"}),
		(["stdin": pythonstdin->pipe(Stdio.PROP_IPC | Stdio.PROP_REVERSE), "stdout": pythonstdout->pipe(Stdio.PROP_IPC)]));
	object tm = System.Timer();
	string template = Stdio.read_file("Nightmare.png");
	while (1) {
		mapping proc = Process.run(({
			"ffmpeg", "-video_size", "1920x1080", "-f", "x11grab", "-i", ":0.0+1920,0",
			"-vframes", "1", "-f", "apng", "-",
		}));
		string screenshot = proc->stdout;
		//screenshot = Stdio.read_file("Grotty.png"); //HACK
		//2. Tesseract
		proc = Process.run(({"tesseract", "-", "-", "hocr"}), (["stdin": screenshot]));
		//3. Parse XML
		array words = list_words(utf8_to_string(proc->stdout));
		//4. Compare to original list
		array pairs = match_arrays(original, words) {[mapping o, mapping d] = __ARGS__;
			return o->text == d->text && (centroid(o->pos) + centroid(d->pos));
		};
		//5. Least-squares linear regression. Currently done in Python+Numpy, would it be worth doing in Pike instead?
		pythonstdin->write(Standards.JSON.encode(pairs, 1) + "\n");
		while (!has_value(pythonbuf, '\n')) {
			pythonbuf += pythonstdout->read(1024, 1);
		}
		sscanf(pythonbuf, "%s\n%s", string line, pythonbuf);
		array matrix = Standards.JSON.decode(line);
		//6. Generate output images
		//As a test, we place a sample box in source coordinates
		array box = ({755, 2104, 1795, 2157});
		Image.Image orig = Image.PNG.decode(template);
		orig->box(@box, 0, 255, 255);
		Image.Image img = Image.PNG.decode(screenshot);
		array points = ({
			xfrm(matrix, box[0], box[1]),
			xfrm(matrix, box[2], box[1]),
			xfrm(matrix, box[2], box[3]),
			xfrm(matrix, box[0], box[3]),
		});
		img->setcolor(0x66, 0x33, 0x99)->polyfill(points * ({ }));
		//Make a single combined file
		constant gutter = 25; //pixels
		constant center = 1; //If 0, the images will be flush top; otherwise they'll be centered vertically in available space.
		//If there's a huge difference in image sizes, rescale until there isn't.
		int origscale = 1, imgscale = 1;
		while (orig->ysize() >= img->ysize() * 2) {origscale *= 2; orig = orig->scale(0.5);}
		while (img->ysize() >= orig->ysize() * 2) {imgscale *= 2; img = img->scale(0.5);}
		Image.Image preview = Image.Image(orig->xsize() + gutter + img->xsize(), max(orig->ysize(), img->ysize()));
		int origy = center && (preview->ysize() - orig->ysize()) / 2;
		int imgx = orig->xsize() + gutter;
		int imgy = center && (preview->ysize() - img->ysize()) / 2;
		preview->paste(orig, 0, origy);
		preview->paste(img, imgx, imgy);
		//For every matched word pair, draw a connecting line
		foreach (pairs, [int x1, int y1, int x2, int y2]) {
			preview->line(x1 / origscale, y1 / origscale + origy,
				x2 / imgscale + imgx, y2 / imgscale + imgy,
				random(256), random(256), random(256));
		}
		Stdio.write_file("preview.png", Image.PNG.encode(preview));
		werror("%d word pairs, %.3fs\n", sizeof(pairs), tm->get());
	}
}
