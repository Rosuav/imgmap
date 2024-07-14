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

int main() {
	//1. Grab a screenshot
	//2. Tesseract
	//3. Parse XML
	//4. Compare to original list
	//5. Least-squares linear regression. Currently done in Python+Numpy, would it be worth doing in Pike instead?
	//6. Generate output images
	array original = list_words(utf8_to_string(Stdio.read_file("Nightmare.hocr")));
	write("Parse result: %O\n", original);
}
