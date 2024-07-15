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
		//Try to advance d1 until we get a match; no further than 4 steps.
		for (int i = 1; i < 5 && d1 + i < sizeof(arr1); ++i) {
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
	//1. Grab a screenshot
	//TODO. For now, using Grotty.png directly.
	string screenshot = Stdio.read_file("Grotty.png");
	//2. Tesseract
	mapping proc = Process.run(({"tesseract", "-", "-", "hocr"}), (["stdin": screenshot]));
	//3. Parse XML
	array words = list_words(utf8_to_string(proc->stdout));
	//4. Compare to original list
	array pairs = match_arrays(original, words) {[mapping o, mapping d] = __ARGS__;
		return o->text == d->text && (centroid(o->pos) + centroid(d->pos));
	};
	//5. Least-squares linear regression. Currently done in Python+Numpy, would it be worth doing in Pike instead?
	proc = Process.run(({"python3.12", "regress.py"}), (["stdin": Standards.JSON.encode(pairs, 1)]));
	if (proc->exitcode) {
		werror("Error from Python: %d\n%s\n", proc->exitcode, proc->stderr);
		return proc->exitcode;
	}
	array matrix = Standards.JSON.decode(proc->stdout);
	//6. Generate output images
	//As a test, we place a sample box in source coordinates
	array box = ({755, 2104, 1795, 2157});
	Image.Image img = Image.PNG.decode(Stdio.read_file("Nightmare.png"));
	img->box(@box, 0, 255, 255);
	Stdio.write_file("template.png", Image.PNG.encode(img));
	img = Image.PNG.decode(screenshot);
	array points = ({
		xfrm(matrix, box[0], box[1]),
		xfrm(matrix, box[2], box[1]),
		xfrm(matrix, box[2], box[3]),
		xfrm(matrix, box[0], box[3]),
	});
	img->setcolor(0x66, 0x33, 0x99)->polyfill(points * ({ }));
	Stdio.write_file("document.png", Image.PNG.encode(img));
}
