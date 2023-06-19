
// EVENT

//const evtSource = new EventSource("/prescription/event.php");

//evtSource.onmessage = (event) => {

	//data = JSON.parse(event.data);

	//data.forEach((prescription) => {
	//	console.log(prescription.id);
	//});
//};

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

// TITLE

function title_on_save() { document.getElementById('title-save').click(); }

// ALERT

function alert_on_save() { document.getElementById('alert-save').click(); }

// DESCRIPTION

function descr_on_save() { document.getElementById('descr-save').click(); }

// PRESCRIPTION

prescription_id = null;

async function prescription_on_update(id) {
	prescription_id = id;
	payload = {'type':'update', 'id':prescription_id};
	const ret = await this.update(payload);
	if (ret.length !== 0) {
		document.getElementById(prescription_id).style.backgroundColor= '#9ec5ef';	
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

