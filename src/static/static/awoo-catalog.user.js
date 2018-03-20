// ==UserScript==
// @name 		awoo catalog
// @namespace 	https://niles.xyz
// @include 	http://boards.lolis.download/*
// @include 	https://niles.lain.city/*
// @include 	http://dangeru.us/*
// @include 	https://dangeru.us/*
// @include 	http://boards.dangeru.us/*
// @include 	https://boards.dangeru.us/*
// @version		1.1
// @grant 		GM_getValue
// @grant 		GM_setValue
// @run-at 		document-end
// ==/UserScript==
var started = false;
var request_in_progress = false;
var out_of_posts = false;
var page = 1;
var to_array = function to_array(thing) {
	return Array.prototype.slice.call(thing, 0)
}
var btnListener = function btnListener(forScroll) {
	if (request_in_progress) return;
	if (out_of_posts && !forScroll) {
		var brd = document.getElementById("board");
		if (brd.tagName.toUpperCase() == "SELECT") {
			brd = "";
		} else {
			brd = brd.value;
		}
		document.location.href = "/archive/" + brd;
		return;
	}
	request_in_progress = true;
	var btn = document.getElementById("load_next_button");
	var href = document.getElementById("pagecount_container").children[0].href;
	var connector = href.match(/(\?|&)page=[0-9]+/)[1];
	var regex_connector = connector == "?" ? "\\?" : connector
	var regex = new RegExp(regex_connector + "page=[0-9]+");
	var url = href.replace(regex, connector + "page=" + page);
	console.log(url);
	page++;
	btn.innerText = "Loading...";
	btn.disabled = true;
	var xhr = new XMLHttpRequest();
	xhr.onreadystatechange = function() {
		var done = this.DONE || 4;
		if (this.readyState === done) {
			console.log("Request done");
			// only replace state on mobile
			if (typeof(UnitedPropertiesIf) != 'undefined')
				history.replaceState({}, window.title, url);
			var parser = new DOMParser();
			var doc = parser.parseFromString(xhr.responseText, "text/html");
			// Fix for android pre-4.4.4
			if (doc == null || doc == undefined) {
				doc = document.implementation.createHTMLDocument("");
				var doc_elt = doc.documentElement;
				doc_elt.innerHTML = xhr.responseText
			}
			var added = 0;
			var page_count_container = document.getElementById("pagecount_container");
			if (page_count_container == null) return;
			var sitecorner = doc.getElementById("sitecorner")
			if (sitecorner == null) sitecorner = doc.getElementById("maincontainer") // advanced_search_results page
			to_array(sitecorner.children).forEach(function(elem) {
				if (!(elem.tagName == "DIV" && (elem.classList.contains("entry") || elem.classList.contains("comment")))) {
					if (elem.tagName != "A" && elem.tagName != "I") return;
				}
				console.log(elem.href)
				if (elem.tagName == "A" && !(elem.hasAttribute("data-replies") || elem.href.indexOf("/ip/") >= 0)) return;
				var newa = document.createElement(elem.tagName);
				to_array(elem.attributes).forEach(function (attr) {
					newa.setAttribute(attr.nodeName, attr.value);
				});
				newa.innerHTML = elem.innerHTML;
				var sc = document.getElementById("sitecorner");
				if (sc == null) sc = document.getElementById("maincontainer");
				if (elem.tagName == "A" && elem.href.indexOf("/ip/") < 0) {
					if (page_count_container.previousElementSibling.tagName.toUpperCase() != "BR")
						sc.insertBefore(document.createElement("br"), page_count_container);
				}
				sc.insertBefore(newa, page_count_container);
				if (elem.tagName == "A") {
					added++;
					doTheThing(newa);
				} else if (elem.tagName == "I") {
					var space = document.createElement("span");
					space.innerText = " ";
					sc.insertBefore(space, newa);
					// THIS DUPLICATES ol BUT IT'S THE DIRTY HACK I NEED RIGHT NOW
					// Also it's broken right now because move doesn't exist
					newa.onmousemove = function(e) { move(e) };
					newa.onmouseover = function() {hover(newa);};
					newa.onmouseout = function() { unhover() };}
			});
			if (added == 0) {
				out_of_posts = true;
				if (document.location.href.indexOf("archive") < 0) {
					btn.innerText = "No more posts. Go to Archive?";
					btn.disabled = false;
				}
			} else {
				btn.disabled = false;
				btn.innerText = "Load page " + (page + 1);
			}
			request_in_progress = false;
		}
	};
	xhr.open("GET", url);
	xhr.send();
};

var apply_one_default = function apply_one_default(key, value) {
	var result = GM_getValue(key, "");
	if (result == null || result == undefined || result.length == 0) {
		GM_setValue(key, value);
	}
}
var apply_defaults = function apply_defaults() {
	apply_one_default("wide", "false");
	apply_one_default("invert", "false");
	apply_one_default("infscroll", "true");
	apply_one_default("bar", "false");
	apply_one_default("scroll_to_bar", "false");
}

var onload = function() {

	// Only start once
	if (started) {
		return;
	}
	started = true;

	apply_defaults();

	var page_count_container = document.getElementById("pagecount_container");
	if (page_count_container != null) {
		board_page_onload();
	} else if (document.getElementById("date_last_modified") != null) {
		replies_page_onload();
	} else {
		generic_onload();
	}
	check_mobile();
	window.init_settings_button("Userscript Options", open_options);
}

var replies_page_onload = function replies_page_onload() {
	var old_replies_count = replies_page_update_key();
	check_wide();
	check_invert();
	// do not check infscroll
	check_bar(old_replies_count);
	check_show_yous();
	check_display_my_id();
};
var board_page_onload = function board_page_onload() {
	// Load new reply count for everything
	to_array(document.getElementsByTagName("a")).forEach(doTheThing);
	check_invert();
	check_infscroll();
	// do not check wide
};
var generic_onload = function board_page_onload() {
	check_invert();
};

var check_infscroll = function check_infscroll() {
	if (GM_getValue("infscroll", "false").toLowerCase() == "true") {
		infscroll();
	}
};
var check_wide = function check_wide() {
	if (GM_getValue("wide", "false").toLowerCase() == "true") {
		go_wide();
	}
};
var check_invert = function check_invert() {
	if (GM_getValue("invert", "false").toLowerCase() == "true") {
		invert();
	}
};
var check_bar = function check_bar(old_replies_count) {
	if (GM_getValue("bar", "false").toLowerCase() == "true") {
		draw_bar(old_replies_count, GM_getValue("scroll_to_bar", "false").toLowerCase() == "true");
	}
};
var check_show_yous = function check_show_yous(old_replies_count) {
	if (GM_getValue("show_yous", "false").toLowerCase() == "true") {
		show_yous();
	}
};
var check_display_my_id = function check_display_my_id(old_replies_count) {
	if (GM_getValue("display_my_id", "false").toLowerCase() == "true") {
		display_my_id();
	}
};
var check_mobile = function check_mobile() {
	if (typeof(unitedPropertiesIf) == "undefined") return;
	var h = document.getElementsByTagName("footer");
	if (h.length == 0) return;
	h = h[0];
	if (h == null) return; // can't be too careful around javascript
	var a = document.createElement("a");
	a.href = "https://github.com/nilesr/United4";
	a.style.fontSize = "x-small";
	a.style.display = "inline-block";
	a.target = "_blank";
	a.classList.add("comment-styled");
	var version;
	try {
		version = " " + to_array(unitedPropertiesIf.getVersionCode().toString()).join(".");
	} catch (e) {
		version = "";
	}
	a.innerText = "la/u/ncher" + version;
	h.appendChild(document.createTextNode(", "));
	h.appendChild(a);
	// Hack for webkit
	a.parentElement.normalize();
	a.previousSibling.data = ", ";
}
var infscroll = function infscroll() {
	var page_count_container = document.getElementById("pagecount_container");
	// Pull the current page from the URL, kind of dirty
	var match_data = document.location.href.match(/(\?|&)page=([0-9]+)/)
	if (match_data != null) page = parseInt(match_data[2]) + 1;

	// Create infinite scrolling "next page" button
	if (document.getElementById("load_next_button") === null) {
		var btn = document.createElement("button");
		btn.classList.add("button_styled");
		btn.id = "load_next_button";
		btn.innerText = "load page " + (page + 1);
		btn.addEventListener("click", function() {
			btnListener(false);
		});
		page_count_container.appendChild(document.createElement("br"));
		page_count_container.appendChild(btn);
	}
	// Initialize infinite scrolling
	if (typeof($) == "undefined") return;
	var doch = function() {
		return $(document).height() - document.getElementById("draggable").clientHeight;
	}
	var win = $(window);
	var winh = function() { return win.height(); };
	if (doch() <= winh()) btnListener(true);
	win.scroll(function() {
		if (doch() - winh() == win.scrollTop()) {
			btnListener(true);
		}
	});
};

var doTheThing = function doTheThing(a) {
	if (!a.hasAttribute("data-replies")) {
		return;
	}

	var board = a.href.split("/")[3];
	var id = a.href.split("/")[5];

	var elem = document.createElement("span");
	a.appendChild(elem);
	elem.innerHTML = "Loading...";

	var key = board + ":" + id;
	var oldreplies = GM_getValue(key, 0);
	var replies = Number(a.getAttribute("data-replies"));
	if (isNaN(replies)) {
		elem.innerHTML = red(a.getAttribute("data-replies"));
		return;
	}
	comparison_and_update_elem(key, replies, a, elem, closed, oldreplies);
};

var grey = function grey(text) {
	return color("grey", text);
};
var red = function red(text) {
	return color("red", text);
};
var color = function color(c, text) {
	return " <span style='color: " + c + ";'>" + text + "</span>";
};

var comparison_and_update_elem = function(key, replies, a, elem, closed, oldreplies) {
	if (oldreplies < replies) {
		elem.innerHTML = red("+" + (replies - oldreplies));
		// we have to wrap this in a closure because otherwise it clicking any post would only update the last post processed in this loop
		set_onclick_listener(key, replies, a, elem, closed);
	} else {
		elem.innerHTML = grey(replies);
	}
};

var set_onclick_listener = function set_onclick_listener(key, replies, a, elem, closed) {
	//console.log(key);
	a.addEventListener("click", function() {
		//GM_setValue(key, replies);
		elem.innerHTML = grey(replies);
	});
};

/*
for wide mode
	on header img
		height: 150px
		width: auto
	on sitecorner
		width: 80%
*/
var go_wide = function go_wide() {
	var img = document.querySelector("#sitecorner > a:nth-child(1) > img");
	if (img != null) {
		//img.style.height = "130px";
		img.style.width = "395px";
	}
	var corner = document.getElementById("sitecorner");
	if (corner == null) corner = document.getElementById("maincontainer");
	if (corner != null) {
		corner.style.width = "80%";
	}
}
/*
for color inversion
	#newthread
	textarea, #draggable > form > input[type='text']
	#boardtitle
	small
	button_styled
		background-color
		border-color
	special_styled
		background-color
		border-color
	a
	.boarda
	#sitecorner
		only border-color
	#title
	.title
	.fa
	--- below here from views ---
	#maincontainer
		border-color
	#draggable
		border-color
	label
	.comment
	form
	#wordcount
*/
var main_bg = "white";
var main_color = "black";
var apply_style = function apply_style(selector, extras) {
	to_array(document.querySelectorAll(selector)).forEach(function(elem) {
		elem.style.color = main_color;
		if (extras != null && extras != undefined) {
			extras.forEach(function(prop) {
				if (prop == "backgroundColor") {
					elem.style[prop] = main_bg;
				} else {
					elem.style[prop] = main_color;
				}
			})
		}
	});
}
var invert = function invert() {
	document.body.style.backgroundColor = main_bg;
	apply_style("#newthread");
	apply_style("textarea, #draggable > form > input[type='text']");
	apply_style("#boardtitle");
	apply_style("small");
	apply_style(".button_styled", ["backgroundColor", "borderColor"]);
	apply_style(".special_styled", ["backgroundColor", "borderColor"]);
	apply_style("a");
	apply_style(".boarda");
	apply_style("#sitecorner", ["borderColor"]);
	apply_style("#title");
	apply_style(".title");
	apply_style(".fa");
	apply_style("#maincontainer", ["borderColor"]);
	apply_style("#draggable", ["borderColor"]);
	apply_style("label");
	apply_style(".comment");
	apply_style("form");
	apply_style("#wordcount");
}

var add_handler = function add_handler(prop) {
	var elem = document.getElementById("enable_" + prop);
	elem.checked = GM_getValue(prop, "false").toLowerCase() == "true";
	elem.addEventListener("change", function() {
		GM_setValue(prop, elem.checked.toString());
	})
}

var open_options = function open_options() {
	/*
	 * there are three cases
	 * mobile (via injection still? can't tell) - have unitedPropertiesIf
	 * desktop via GM - have GM_setValue;
	 * desktop via injection - have localStorage aliased in via GM_setValue
	 */
	document.getElementById("options_button").outerHTML = "";
	var all_options = document.createElement("div");
	all_options.id = "all_options";
	/*
<div style="z-index: 100; font-size: 1em; font-family: sans-serif; background-color: #ddd; color: black; position: fixed; top: 10%; left: 10%; width: 60%; padding: 10%;">
	Changes will take effect when you reload the page.<br />
	<input type="checkbox" id="enable_wide" name="enable_wide" /><label for="enable_wide">Wide mode</label><br />
	<input type="checkbox" id="enable_invert" name="enable_invert" /><label for="enable_invert">Invert colors</label><br />
	<input type="checkbox" id="enable_infscroll" name="enable_infscroll" /><label for="enable_infscroll">Infinite scrolling</label><br />
	<input type="checkbox" id="enable_bar" name="enable_bar" /><label for="enable_bar">Draw bar at beginning of new replies</label><br />
	<input type="checkbox" id="enable_scroll_to_bar" name="enable_scroll_to_bar" /><label for="enable_scroll_to_bar">Jump to bar on load</label><br />
	<input type="checkbox" id="enable_show_yous" name="enable_show_yous" /><label for="enable_show_yous">Display (You)s and (OP)s</label><br />
	<input type="checkbox" id="enable_display_my_id" name="enable_display_my_id" /><label for="enable_display_my_id">Show me my ID</label><br />
	<button id="disable_userscript">Disable userscript</button><br />
	<button id="userscript_close">Save and reload</button>
	<button id="read_all">Mark all visible posts as read</button>
</div>
	 */
	all_options.innerHTML = "<div style=\"z-index: 100; font-size: 1em; font-family: sans-serif; background-color: #ddd; color: black; position: fixed; top: 10%; left: 10%; width: 60%; padding: 10%;\">\n\tChanges will take effect when you reload the page.<br />\n\t<input type=\"checkbox\" id=\"enable_wide\" name=\"enable_wide\" /><label for=\"enable_wide\">Wide mode</label><br />\n\t<input type=\"checkbox\" id=\"enable_invert\" name=\"enable_invert\" /><label for=\"enable_invert\">Invert colors</label><br />\n\t<input type=\"checkbox\" id=\"enable_infscroll\" name=\"enable_infscroll\" /><label for=\"enable_infscroll\">Infinite scrolling</label><br />\n\t<input type=\"checkbox\" id=\"enable_bar\" name=\"enable_bar\" /><label for=\"enable_bar\">Draw bar at beginning of new replies</label><br />\n\t<input type=\"checkbox\" id=\"enable_scroll_to_bar\" name=\"enable_scroll_to_bar\" /><label for=\"enable_scroll_to_bar\">Jump to bar on load</label><br />\n\t<input type=\"checkbox\" id=\"enable_show_yous\" name=\"enable_show_yous\" /><label for=\"enable_show_yous\">Display (You)s and (OP)s</label><br />\n\t<input type=\"checkbox\" id=\"enable_display_my_id\" name=\"enable_display_my_id\" /><label for=\"enable_display_my_id\">Show me my ID</label><br />\n\t<button id=\"disable_userscript\">Disable userscript</button><br />\n\t<button id=\"userscript_close\">Save and reload</button>\n\t<button id=\"read_all\">Mark all visible posts as read</button>\n</div>\n";
	document.body.appendChild(all_options);
	add_handler("invert");
	add_handler("wide");
	add_handler("infscroll");
	add_handler("bar");
	add_handler("scroll_to_bar");
	add_handler("show_yous");
	add_handler("display_my_id");
	document.getElementById("disable_userscript").addEventListener("click", function() {
		if (typeof(unitedPropertiesIf) != "undefined") {
			unitedPropertiesIf.toast("To disable userscript on mobile, click the three dots in the top right then click Settings.");
			return;
		}
		GM_setValue("userscript", "false");
		document.location.reload();
	});
	document.getElementById("userscript_close").addEventListener("click", function() {
		all_options.outerHTML = "";
		document.location.reload();
	});
	document.getElementById("read_all").addEventListener("click", function() {
		to_array(document.getElementsByTagName("a")).forEach(function(a) {
			var board = a.href.split("/")[3];
			var id = a.href.split("/")[5];
			var replies = Number(a.getAttribute("data-replies"));
			if (isNaN(replies)) return;
			var key = board + ":" + id;
			GM_setValue(key, replies);
			document.location.reload();
		})
	});
};
var draw_bar = function draw_bar(old_read_count, scroll_to) {
	var submit = document.getElementById("submit");
	if (submit != null) {
		submit.onclick = hooked_submit;
	}
	if (old_read_count == -1) return;
	var comments = to_array(document.getElementsByClassName("comment")).filter(function(elem) { return elem.id != "hover"; });
	var bar = document.createElement("hr");
	bar.id = "bar";
	try {
		if (typeof(unitedPropertiesIf) != "undefined") {
			var i = parseInt(unitedPropertiesIf.getProperty("toolbar_color"))
			if (isNaN(i) || i == 0) throw 0;
			i &= 0xFFFFFF;
			var c = i.toString(16);
			while (c.length < 6) c = "0" + c;
			bar.style.borderTopColor = "#" + c
		}
	} catch (e) {
		// drop
	}
	document.getElementById("sitecorner").insertBefore(bar, comments[old_read_count]);
	var br = bar.previousElementSibling;
	if (br.tagName.toUpperCase() == "BR") br.outerHTML = ""
	if (scroll_to) {
		bar.scrollIntoView(true);
	}
};
var replies_page_update_key = function replies_page_update_key() {
	var key = window.board + ":" + window.id;
	var old_read_count = GM_getValue(key, -1);
	GM_setValue(key, total_number_of_posts);
	if (old_read_count == total_number_of_posts) old_read_count = -1;
	return old_read_count;
};

var hooked_submit = function hooked_submit() {
	var key = window.board + ":" + window.id;
	GM_setValue(key, total_number_of_posts + 1);
	submit_form(document.getElementById("form"), "/reply");
};

var show_yous = function show_yous() {
	to_array(document.getElementsByClassName("referencer")).forEach(function(elem) {
		var refers_to = elem.getAttribute("data-refers-to");
		if (refers_to == window.id) {
			elem.innerText += " (OP)"
		}
		var is = elem.getAttribute("data-is");
		var _parent = document.getElementById("comment-" + refers_to);
		if (_parent == null) return;
		_parent = _parent.getElementsByClassName("post_number")[0];
		parent_hash = _parent.getElementsByClassName("hash")[0];
		if (parent_hash.innerText == window.your_hash) {
			elem.innerText += " (You)";
		}
	});
};
var display_my_id = function display_my_id() {
	var reply_box = document.getElementById("reply_box");
	if (reply_box == null) return;
	var n = document.createElement("span");
	n.innerText = "Replying as:"
	var s = document.createElement("span");
	s.style.backgroundColor = "#" + window.your_hash;
	s.innerText = window.your_hash;
	s.style.padding = "2px";
	s.style.borderRadius = "3px";
	var color = parseInt(window.your_hash, 16);
	var r = color & 0xFF0000, g = color & 0xFF00, b = color & 0xFF;
	r >>= 16; g >>= 8;
	r += 127; g += 127; b += 127;
	r &= 0xFF; g &= 0xFF; b &= 0xFF;
	color = (r << 16) + (g << 8) + b;
	color = color.toString(16);
	while (color.length < 6) color = "0" + color;
	s.style.color = "#" + color;
	n.appendChild(s)
	n.style.float = "left";
	n.classList.add("comment-styled");
	reply_box.parentNode.insertBefore(n, reply_box);
};


// In chrome, the userscript runs in a sandbox, and will never see these events
// Hence the run-at document-end
//document.addEventListener('DOMContentLoaded', onload);
//document.onload = onload;

// One of these should work, and the started variable should prevent it from starting twice (I hope)
function GM_main() {
	onload();
}
onload();
