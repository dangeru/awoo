var thread_watcher_threads;
var thread_watcher_read = function thread_watcher_read() {
	try {
		thread_watcher_threads = JSON.parse(localStorage.getItem("watched_threads", "[]")) || [];
	} catch (e) {
		thread_watcher_threads = [];
	}
}
var thread_watcher_write = function thread_watcher_write() {
	localStorage.setItem("watched_threads", JSON.stringify(thread_watcher_threads));
}
var thread_watcher_same_arrays = function(a, b) {
	if (a.length != b.length) return false;
	for (var i = 0; i < a.length; i++) {
		if (a[i] != b[i]) {
			return false;
		}
	}
	return true;
}
var thread_watcher_init = function thread_watcher_init() {
	thread_watcher_box.innerHTML = "";
	thread_watcher_threads.forEach(function(id) {
		var div = document.createElement("div");
		div.innerText = "Loading...";
		thread_watcher_box.appendChild(div);
	});
}
var thread_watcher_remove = function thread_watcher_remove(id) {
	var old_list = thread_watcher_threads;
	thread_watcher_read();
	var same = thread_watcher_same_arrays(old_list, thread_watcher_threads);
	var index = thread_watcher_threads.indexOf(id);
	if (index >= 0) {
		thread_watcher_threads.splice(index, 1);
		if (same) {
			thread_watcher_box.children[index].outerHTML = "";
		}
	}
	thread_watcher_write();
	if (!same) {
		thread_watcher_init();
		thread_watcher_update();
		thread_watcher_render_warning();
		thread_watcher_render_toggle();
	}
	return same;
}
var thread_watcher_add = function thread_watcher_add(id) {
	var old_list = thread_watcher_threads;
	thread_watcher_read();
	var same = thread_watcher_same_arrays(old_list, thread_watcher_threads);
	thread_watcher_threads.push(id);
	thread_watcher_write();
	if (!same) {
		thread_watcher_init();
		thread_watcher_update();
		thread_watcher_render_warning();
		thread_watcher_render_toggle();
	}
	return same;
}
thread_watcher_read();
var thread_watcher_box = document.createElement("div");
thread_watcher_box.style.display = "none";
thread_watcher_box.id = "thread_watcher_box";
var thread_watcher_wrapper = document.createElement("div");
var thread_watcher_header = document.createElement("div");
thread_watcher_header.classList.add("thread_watcher_padding");
thread_watcher_header.innerText = "Thread Watcher";
var thread_watcher_updated_first = false;
thread_watcher_header.addEventListener("click", function() {
	if (thread_watcher_box.style.display == "none") {
		thread_watcher_box.style.display = "block";
		thread_watcher_toggle.style.display = "block";
		thread_watcher_render_warning();
		if (!thread_watcher_updated_first) {
			thread_watcher_update();
		}
	} else {
		thread_watcher_box.style.display = "none";
		thread_watcher_toggle.style.display = "none";
		thread_watcher_warning.style.display = "none";
	}
	var special = thread_watcher_box.style.display == "block" && thread_watcher_toggle.parentNode == null && thread_watcher_warning.style.display == "none";
	thread_watcher_wrapper.style.paddingBottom = special ? "0px" : "10px";
	thread_watcher_updated_first = true;
})
thread_watcher_wrapper.id = "thread_watcher";
thread_watcher_wrapper.appendChild(thread_watcher_header);
thread_watcher_wrapper.appendChild(thread_watcher_box);
var thread_watcher_toggle = document.createElement("div");
thread_watcher_toggle.style.display = "none";
thread_watcher_toggle.classList.add("thread_watcher_padding");
if (window.id != null && window.board != null) {
	thread_watcher_wrapper.appendChild(thread_watcher_toggle);
	var thread_watcher_render_toggle = function thread_watcher_render_toggle() {
		thread_watcher_toggle.innerHTML = "";
		if (thread_watcher_threads.indexOf(window.id) >= 0) {
			thread_watcher_toggle.innerText = "Unwatch Thread";
		} else {
			thread_watcher_toggle.innerText = "Watch Thread";
		}
	}
	thread_watcher_render_toggle();
	thread_watcher_toggle.addEventListener("click", function() {
		var index = thread_watcher_threads.indexOf(window.id);
		if (index >= 0) {
			thread_watcher_remove(thread_watcher_threads[index])
		} else {
			if (thread_watcher_add(window.id)) {
				var newdiv = document.createElement("div");
				newdiv.innerText = "Loading...";
				thread_watcher_box.appendChild(newdiv);
				thread_watcher_update_one(window.id, thread_watcher_threads.length - 1)
			}
		}
		thread_watcher_render_warning();
		thread_watcher_render_toggle();
	})
}
thread_watcher_init();
var thread_watcher_warning = document.createElement("div");
thread_watcher_warning.classList.add("thread_watcher_padding");
thread_watcher_wrapper.appendChild(thread_watcher_warning);
thread_watcher_warning.innerText = "You are not watching any threads";
var thread_watcher_render_warning = function thread_watcher_render_warning() {
	thread_watcher_warning.style.display = thread_watcher_threads.length == 0 ? "block" : "none";
}
thread_watcher_warning.style.display = "none";
document.body.appendChild(thread_watcher_wrapper);
var thread_watcher_update_one = function(id, i) {
	var thread_watcher_children = thread_watcher_box.children;
	var make_x = function make_x(id, div) {
		var i = document.createElement("i");
		i.classList.add("fa");
		i.classList.add("fa-times");
		i.style.float = "right";
		i.addEventListener("click", function() {
			if (thread_watcher_remove(id)) {
				thread_watcher_render_warning();
				thread_watcher_render_toggle();
			}
		});
		return i;
	}
	var make_refresh = function make_refresh(id, div) {
		var i = document.createElement("i");
		i.classList.add("fa");
		i.classList.add("fa-refresh");
		i.style.float = "right";
		i.addEventListener("click", function() {
			div.innerHTML = "";
			div.innerText = "Loading...";
			thread_watcher_update_one(id, thread_watcher_threads.indexOf(id));
		});
		return i;
	}
	var handle_response = function handle_response(i, thread) {
		var div = thread_watcher_children[i];
		div.innerHTML = "";
		var a = document.createElement("a");
		a.style.display = "inline-block";
		a.href = "/" + thread.board + "/thread/" + thread.post_id;
		var seen = Number(localStorage.getItem(thread.board + ":" + thread.post_id, "0"));
		if (isNaN(seen)) seen = 0;
		var new_replies = thread.number_of_replies - seen
		var text = thread.title;
		if (new_replies > 0) {
			text += " (" + new_replies + ")"
			a.classList.add("thread_watcher_new");
			a.addEventListener("click", function() {
				a.classList.remove("thread_watcher_new");
				a.innerText = thread.title;
			});
		}
		a.innerText = text;
		div.appendChild(a);
		div.appendChild(make_refresh(thread.post_id, div));
		div.appendChild(make_x(thread.post_id, div));
	}
	var handle_error = function handle_error(i) {
		var div = thread_watcher_children[i];
		div.innerHTML = "";
		div.innerText = "Thread " + thread_watcher_threads[i].toString() + " error."
		div.appendChild(make_x(i, div));
	}
	var xhr = new XMLHttpRequest();
	xhr.onreadystatechange = function() {
		var done = this.DONE || 4;
		if (this.readyState != done) return;
		var thread;
		try {
			thread = JSON.parse(xhr.responseText);
			handle_response(i, thread);
		} catch (e) {
			handle_error(i);
		}
	};
	xhr.open("GET", "/api/v2/thread/" + id + "/metadata");
	xhr.send();
};
var thread_watcher_update = function thread_watcher_update() {
	for (var i = 0; i < thread_watcher_threads.length; i++) {
		thread_watcher_update_one(thread_watcher_threads[i], i);
	}
}
