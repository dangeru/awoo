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
