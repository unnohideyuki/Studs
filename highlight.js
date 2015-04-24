// This JavaScript code is from tDiary's highlight plughin (highlight.rb),
// just slightly modified for Studs.
var highlightElem = null;
var saveClass = null;

function highlightElement(name) {
    if (highlightElem) {
	highlightElem.className = saveClass;
	highlightElem = null;
    }

    highlightElem = getHighlightElement(name);
    if (!highlightElem) return;

	saveClass = highlightElem.className;
    highlightElem.className = "highlight";
}
			
function getHighlightElement(id) {
    return document.getElementById(id);
}
		
function handleLinkClick() {
    highlightElement(this.hash.substr(1));
}

function dohighlight(){
    if (document.location.hash) {
	highlightElement(document.location.hash.substr(1));
    }
			
    hereURL = document.location.href.split(/#/)[0];
    for (var i=0; i<document.links.length; ++i) {
	if (hereURL == document.links[i].href.split(/#/)[0]) {
	    document.links[i].onclick = handleLinkClick;
	}
    }
}
