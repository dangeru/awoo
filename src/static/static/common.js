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
var unban = function unban(addr, board) {
	alert("You tried to unban " + addr + " from the board " + board + ", but it's not implemented yet");
}
var doWordcount = function doWordcount(comment_id) {
	document.getElementById(comment_id).addEventListener("keyup", function() {
		var comment = document.getElementById(comment_id);
		console.log(comment.value.length);
		var len = (comment.value.length * 1.03) | 0;
		var wc = document.getElementById("wordcount");
		var submit = document.getElementById("submit");
		wc.style.color = len > 500 ? "red" : "inherit";
		if (submit != null) {
			submit.disabled = len > 500 ? true : false;
			submit.className = len > 500 ? "special_styled" : "button_styled";
		}
		wc.innerText = len + "/500";
	});
}
