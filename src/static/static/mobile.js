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
}

