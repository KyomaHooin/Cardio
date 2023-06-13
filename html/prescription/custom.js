
// MODAL

modal = new bootstrap.Modal(document.getElementById('modal'));
modal_action = null;

function on_confirm() {
	if (modal_action == 'prescription-remove') { document.getElementById('prescription-remove').click(); }
	if (modal_action == 'prescription-remove') { document.getElementById('prescription-remove').click(); }
}

// FETCH  - JSON { type, value } response JSON { value }

async function update(payload) {
	return await fetch('/settings/', {
		method: 'POST',
		headers: {'Content-Type' :'application/json'},
		body: JSON.stringify(payload)
	})
	.then(response => response.json())
	.then(data => {
		 return data;
	})
	.catch(error => {
		console.error(error);
		return;
	});
}

function alert_on_save() { document.getElementById('alert-save').click(); }

function prescription_on_save() {
	modal.toggle();
	modal_action = 'prescription-remove';
}

function prescription_on_mark() {
}


async function remove_prescription(id) {
	const ret = await this.update(payload);
	if (ret === 'ok') {
		document.getElementById(id).style.display = 'none';	
	}
}

