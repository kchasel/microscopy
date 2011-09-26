// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

function getWindowHeight() {
    var windowHeight = 0;
    if (typeof(window.innerHeight) == 'number') {
        windowHeight = window.innerHeight;
    }
    else {
        if (document.documentElement && document.documentElement.clientHeight) {
            windowHeight = document.documentElement.clientHeight;
        }
        else {
            if (document.body && document.body.clientHeight) {
                windowHeight = document.body.clientHeight;
            }
        }
    }
    return windowHeight;
}

function stickToBottom() {
	if (document.getElementById) {
		var windowHeight=getWindowHeight();
		if (windowHeight > 0) {
			var slidebox=document.getElementById('slidebox');
			var topbox=document.getElementById('topbox');
			var topboxHeight = topbox.offsetHeight;
			if (windowHeight - topboxHeight > 0) {
			    slidebox.style.height=(windowHeight - topboxHeight - 8) + 'px';
			}
		}
	}
}

function raise_bottombar() {
	if ($('pathway').visible() == false) {
		new Effect.BlindDown("pathway",{duration:0.1});
		$('minusbox').show();
	}
	else {
	    new Effect.BlindUp("pathway",{duration:0.1});
		$('minusbox').hide();
	}
}

function update_order_field_for_sortables()
{
	$('pathway_order').value = Sortable.serialize('new-pathway-list');
}
