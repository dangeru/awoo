var deletePost = function deletePost(id) {
	//window.open("/delete/" + id.toString());
	window.location.href = "/delete/" + id.toString();
}
var lockPost = function lockPost(id) {
	window.location.href = "/lock/" + id.toString();
}
var unlockPost = function unlockPost(id) {
	window.location.href = "/unlock/" + id.toString();
}
var stickyPost = function unlockPost(id) {
	window.location.href = "/sticky/" + id.toString();
}
var unstickyPost = function unlockPost(id) {
	window.location.href = "/unsticky/" + id.toString();
}
var uncapcodePost = function uncapcodePost(id) {
	window.location.href = "/uncapcode/" + id.toString();
}
var capcodePost = function capcodePost(id) {
	var xhr = new XMLHttpRequest();
	xhr.onreadystatechange = function() {
		if (xhr.readyState == 4) {
			if (xhr.status != 200) {
				alert("errno = -EINVAL; return;\n\n" + xhr.responseText)
			}
			var list = JSON.parse(xhr.responseText);
			var existing_dialog = document.getElementById("capcode_dialog");
			if (existing_dialog != null) existing_dialog.outerHTML = "";
			var dialog = document.createElement("div");
			document.body.appendChild(dialog);
			/*
<div style="z-index: 100; font-size: 1em; font-family: sans-serif; background-color: #ddd; color: black; position: fixed; top: 10%; left: 10%; width: 60%; padding: 10%;" id="capcode_dialog">
	Select the capcode for the post with id <span id="capcode_dialog_post_id"></span><br />
	<select name="capcode" id="capcode_dialog_capcode">
	  <option value="_hidden">Hidden</option>
	</select>
	<br />
	<button id="capcode_dialog_save">Go</button>
	<button id="capcode_dialog_dismiss">Cancel</button>
</div>
*/
			dialog.outerHTML = "<div style=\"z-index: 100; font-size: 1em; font-family: sans-serif; background-color: #ddd; color: black; position: fixed; top: 10%; left: 10%; width: 60%; padding: 10%;\" id=\"capcode_dialog\">\n\tSelect the capcode for the post with id <span id=\"capcode_dialog_post_id\"></span><br />\n\t<select name=\"capcode\" id=\"capcode_dialog_capcode\">\n\t  <option value=\"_hidden\">Hidden</option>\n\t</select>\n\t<br />\n\t<button id=\"capcode_dialog_save\">Go</button>\n\t<button id=\"capcode_dialog_dismiss\">Cancel</button>\n</div>\n"
			document.getElementById("capcode_dialog_post_id").innerText = id;
			var dropdown = document.getElementById("capcode_dialog_capcode");
			list.forEach(function(elem) {
				if (elem == "_hidden") return;
				var option = document.createElement("option")
				option.value = elem;
				option.innerText = elem;
				dropdown.appendChild(option);
			});
			document.getElementById("capcode_dialog_save").addEventListener("click", function() {
				window.location.href = "/capcode/" + id + "?capcode=" + encodeURIComponent(dropdown.selectedOptions[0].value);
			});
			document.getElementById("capcode_dialog_dismiss").addEventListener("click", function() {
				document.getElementById("capcode_dialog").outerHTML = "";
			});
		}
	}
	xhr.open("GET", "/api/v2/allowed_capcodes");
	xhr.send();
}
var doWordcount = function doWordcount(comment_id, mod) {
	var comment = document.getElementById(comment_id);
	if (comment == null) return;
	comment.addEventListener("keyup", function() {
		//console.log(comment.value.length);
		var len = (comment.value.length * 1.03) | 0;
		var wc = document.getElementById("wordcount");
		var submit = document.getElementById("submit");
		if (len > 500 && !mod) {
			wc.classList.add("red");
			wc.classList.remove("comment-styled");
		} else {
			wc.classList.remove("red");
			wc.classList.add("comment-styled");
		}
		if (submit != null) {
			submit.disabled = len > 500 && !mod;
			submit.className = (len > 500 && !mod) ? "special_styled" : "button_styled";
		}
		wc.innerText = len + "/" + (mod ? "Unlimited" : "500");
		var lines = comment.value.split("\n");
		var total_count = lines.length;
		if (comment.value[comment.value.length - 1] == "\n")
			total_count++;
		for (var i = 0; i < lines.length; i++) {
			var num_chars = lines[i].length;
			var effective_width = num_chars * 10.3; // approx 10.1 but better be safe
			var effective_lines = Math.ceil(effective_width / comment.clientWidth);
			var extra_lines = effective_lines - 1;
			total_count += extra_lines;
		}
		var minimum_height = total_count * 21.5; // approx 21 but better be safe
		console.log("min: " + minimum_height + " actual: " + comment.style.height)
		if (comment.style.height == null || comment.style.height == "")
			comment.style.height = comment.clientHeight + "px"
		if (Number(comment.style.height.replace("px", "")) < minimum_height)
			comment.style.height = minimum_height + "px";
	});
}
