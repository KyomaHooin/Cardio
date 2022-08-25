

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

	id = String(last_prescription());
	prescription = document.createDocumentFragment();

	row = document.createElement('div');
	row.className = 'row g-3 row-cols-md-3 d-grid d-sm-flex';
	col = document.createElement('div');
	col.className = 'col';
	head = document.createElement('h4');
	head.className = 'mt-4';
	head.innerText = 'Lék ' + id;
	input = document.createElement('input');
	input.className = 'form-control';
	input.id = 'prescription' + id;
	input.name = 'prescription' + id;
	input.type = 'text';
	col.appendChild(head);
	col.appendChild(input);
	row.appendChild(col);
	prescription.appendChild(row);

	col = document.createElement('div');
	col.className = 'col';
	head = document.createElement('h4');
	head.className = 'mt-4';
	head.innerText = 'gramáž';
	input = document.createElement('input');
	input.className = 'form-control';
	input.id = 'volume' + id;
	input.name = 'volume' + id;
	input.type = 'text';
	col.appendChild(head);
	col.appendChild(input);
	row.appendChild(col);
	prescription.appendChild(row);

	col = document.createElement('div');
	col.className = 'col';
	head = document.createElement('h4');
	head.className = 'mt-4';
	head.innerText = 'dávkování';
	input = document.createElement('input');
	input.className = 'form-control';
	input.id = 'dosage' + id;
	input.name = 'dosage' + id;
	input.type = 'text';
	col.appendChild(head);
	col.appendChild(input);
	row.appendChild(col);
	prescription.appendChild(row);

	document.getElementById('prescriptions').appendChild(prescription);

	if ( !id || id === '10') {
		document.getElementById('add-prescription').style.display = 'none';	
	}
}

