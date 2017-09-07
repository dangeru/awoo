if (typeof(unitedPropertiesIf) != "undefined") {
  var sc = document.getElementById("sitecorner")
  if (sc != null) {
	sc.style.margin = "0";
	sc.style.border = "none";
	sc.style.width = "100%";
	sc.style.padding = "0";
  }
  var header = document.getElementsByTagName("img")[0];
  if (header != null) {
	header.style.width = "100%";
	header.style.height = "auto";
  }
  var draggable = document.getElementById("draggable");
  if (draggable != null) {
	document.getElementById("draggable").style.width = "auto";
  }
  var mc = document.getElementById("maincontainer");
  if (mc != null) {
	mc.style.margin = "0";
	mc.style.border = "none";
	mc.style.padding = "0";
	mc.style.borderRadius = "0";
	mc.style.width = "100%";
  }
} else {
  var userscript = localStorage.getItem("userscript") == "true";
  var toggle = function toggle() {
    localStorage.setItem("userscript", !userscript);
    window.location.reload();
  }
  var options = document.createElement("span");
  options.style.opacity = 0;
  options.innerText = "Toggle Userscript (currently "+(userscript ? "on" : "off")+")";
  options.style.backgroundColor = "white";
  options.style.color = "black";
  options.addEventListener("mouseover", function() {
    options.style.opacity = 1;
  });
  options.addEventListener("mouseout", function() {
    options.style.opacity = 0;
  });
  options.addEventListener("click", toggle);
  options.style.position = "fixed";
  options.style.top = "10px";
  options.style.right = "10px";
  options.style.padding = "3px";
  options.style.borderRadius = "3px";
  document.getElementsByTagName("body")[0].appendChild(options);
  if (userscript) {
    var s = document.createElement("script");
    s.src = "/static/awoo-catalog/awoo-catalog.user.js";
    window.GM_setValue = function GM_setValue(k, v) { localStorage.setItem(k, v); };
    window.GM_getValue = function GM_getValue(k, d) { 
      var value = localStorage.getItem(k);
      return value == null ? d : value;
    };
    document.getElementsByTagName("head")[0].appendChild(s);
  }
}
