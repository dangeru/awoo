var add_script = function add_script() {
  var s = document.createElement("script")
  s.src = "/static/awoo-catalog/awoo-catalog.user.js"
  document.getElementsByTagName("head")[0].appendChild(s);
}
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
  if (unitedPropertiesIf.getProperty("userscript").toUpperCase() == "TRUE") {
    window.GM_getValue = function(a, b) {
      var res = unitedPropertiesIf.getProperty(a);
      if (res == "") return b;
      return res;
    }
    window.GM_setValue = function(a, b) {
      unitedPropertiesIf.setProperty(a, b);
    }
    add_script();
  }
} else {
  var userscript = localStorage.getItem("userscript") == "true";
  if (userscript) {
    window.GM_setValue = function GM_setValue(k, v) { localStorage.setItem(k, v); };
    window.GM_getValue = function GM_getValue(k, d) { 
      var value = localStorage.getItem(k);
      return value == null ? d : value;
    };
    add_script();
  } else {
    var enable = function enable() {
      localStorage.setItem("userscript", true);
      window.location.reload();
    }
    var options = document.createElement("span");
    options.style.opacity = 0;
    options.innerText = "Toggle Userscript (currently off)";
    options.style.backgroundColor = "white";
    options.style.color = "black";
    options.addEventListener("mouseover", function() {
      options.style.opacity = 1;
    });
    options.addEventListener("mouseout", function() {
      options.style.opacity = 0;
    });
    options.addEventListener("click", enable);
    options.style.position = "fixed";
    options.style.bottom = "10px";
    options.style.left = "10px";
    options.style.padding = "3px";
    options.style.borderRadius = "3px";
    document.body.appendChild(options);
  }
}
