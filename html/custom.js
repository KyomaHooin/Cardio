
// DROP PRESCRIPTION

async function _drop_prescription(id) {
	return await fetch('/prescription/', {
		method: 'POST',
		body: 'drop:' + id
	})
	.then(response => {
		if (!response.ok) {
			throw new Error('Network error.');
	}
		 return response.text();
	})
	.catch(error => {
		console.error(error);
		return error;
	});
}

async function remove_prescription(id) {
	const ret = await this.drop_prescription(id);
	if (ret === 'ok') {
		document.getElementById(id).style.display = 'none';	
	}
}

// INSERT PRESCRIPTION

function insertAfter(newNode, referenceNode) {
    referenceNode.parentNode.insertBefore(newNode, referenceNode.nextSibling);
}

function last_prescription() {
	prescriptions = document.getElementsByTagName('input');
	last = prescriptions[prescriptions.length - 1].id;
	id = last.match('\\d+')
	if (Array.isArray(id) && id.length) {
		return Number(id[0]) + 1
	} else {
		return null;
	}
}

function add_prescription() {

	id = last_prescription();
	prescription = document.createDocumentFragment();

	hr = document.createElement('hr');
	prescription.appendChild(hr);

	row = document.createElement('div');
	row.className = 'row g-3 row-cols-md-3 d-grid d-sm-flex';

	col = document.createElement('div');
	col.className = 'col';
	head = document.createElement('h4');
	head.innerText = 'Lék ' + String(id + 1);
	input = document.createElement('input');
	input.className = 'form-control';
	input.id = 'prescription' + String(id);
	input.name = 'prescription[' + String(id) + '][prescription]';
	input.type = 'text';
	input.maxLength = '30';
	col.appendChild(head);
	col.appendChild(input);
	row.appendChild(col);
	//prescription.appendChild(row);

	col = document.createElement('div');
	col.className = 'col';
	head = document.createElement('h4');
	head.innerText = 'gramáž';
	input = document.createElement('input');
	input.className = 'form-control';
	input.id = 'volume' + String(id);
	input.name = 'prescription[' + String(id) + '][volume]';
	input.type = 'text';
	input.maxLength = '10';
	col.appendChild(head);
	col.appendChild(input);
	row.appendChild(col);
	//prescription.appendChild(row);

	col = document.createElement('div');
	col.className = 'col';
	head = document.createElement('h4');
	head.innerText = 'dávkování';
	input = document.createElement('input');
	input.className = 'form-control';
	input.id = 'dosage' + String(id);
	input.name = 'prescription[' + String(id) + '][dosage]';
	input.type = 'text';
	input.maxLength = '10';
	col.appendChild(head);
	col.appendChild(input);
	row.appendChild(col);
	prescription.appendChild(row);

	document.getElementById('prescriptions').appendChild(prescription);

	if ( !id || String(id) === '9') {
		document.getElementById('add-prescription').style.display = 'none';	
	}
}

