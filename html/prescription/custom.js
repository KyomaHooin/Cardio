
// MODAL

modal = new bootstrap.Modal(document.getElementById('modal'));

// FETCH  - JSON { type, value } response JSON { value }

async function update(payload) {
	return await fetch('/prescription/', {
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

// ALERT

function alert_on_save() { document.getElementById('alert-save').click(); }

// PRESCRIPTION

prescription_id = null;

async function prescription_on_update(id) {
	prescription_id = id;
	payload = {'type':'update', 'id':prescription_id};
	const ret = await this.update(payload);
	if (ret.length !== 0) {
		document.getElementById(prescription_id).style.backgroundColor= '#fff3cd';	
	}
}

async function prescription_on_remove(id) {
	prescription_id = id;
	modal.toggle();
}

async function prescription_remove() {
	payload = {'type':'remove', 'id':prescription_id};
	const ret = await this.update(payload);
	if (ret.length !== 0) {
		document.getElementById(prescription_id).style.display = 'none';	
	}
	modal.toggle();
}

