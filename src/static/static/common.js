var deletePost = function deletePost(id) {
	window.open("/delete/" + id.toString());
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
var uncapcode = function uncapcode(id) {
	window.location.href = "/uncapcode/" + id.toString();
}
var unban = function unban(addr, board) {
	alert("You tried to unban " + addr + " from the board " + board + ", but it's not implemented yet");
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
			submit.disabled = (len > 500 && !mod) ? true : false;
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
