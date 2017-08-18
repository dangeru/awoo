var deletePost = function deletePost(id) {
	window.open("/delete/" + id.toString());
}
var lockPost = function lockPost(id) {
	window.location.href = "/lock/" + id.toString();
}
var unlockPost = function unlockPost(id) {
	window.location.href = "/unlock/" + id.toString();
}

