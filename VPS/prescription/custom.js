
// MODAL

modal = new bootstrap.Modal(document.getElementById('modal'));

// FETCH  - JSON { type, value } response JSON { value }

async function update(payload) {
	return await fetch('/', {
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

// TEXT

function text_on_save() { document.getElementById('text-save').click(); }

// STATUS

async function status_update(state) {
	payload = {'type':'offline', 'state':state};
	const ret = await this.update(payload);
}

// PRESCRIPTION

prescription_id = null;

async function prescription_on_update(id) {
	prescription_id = id;
	payload = {'type':'update', 'id':prescription_id};
	const ret = await this.update(payload);
	if (ret.length !== 0) {
		document.getElementById(prescription_id).style.backgroundColor= '#adb5bd';
		data = document.getElementById('data-' + prescription_id);
		data.removeChild(data.firstChild);
		data.textContent = ret['value'];
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

