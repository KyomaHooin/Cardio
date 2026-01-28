
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
	label = document.createElement('label');
	label.htmlFor = 'prescription' + String(id);
	head = document.createElement('h4');
	head.innerText = 'Lék ' + String(id + 1);
	input = document.createElement('input');
	input.className = 'form-control fw-bold';
	input.id = 'prescription' + String(id);
	input.name = 'prescription[' + String(id) + '][prescription]';
	input.type = 'text';
	input.maxLength = '25';
	label.appendChild(head);
	col.appendChild(label);
	col.appendChild(input);
	row.appendChild(col);

	col = document.createElement('div');
	col.className = 'col';
	label = document.createElement('label');
	label.htmlFor = 'volume' + String(id);
	head = document.createElement('h4');
	head.innerText = 'gramáž';
	input = document.createElement('input');
	input.className = 'form-control fw-bold';
	input.id = 'volume' + String(id);
	input.name = 'prescription[' + String(id) + '][volume]';
	input.type = 'text';
	input.maxLength = '15';
	label.appendChild(head);
	col.appendChild(label);
	col.appendChild(input);
	row.appendChild(col);

	col = document.createElement('div');
	col.className = 'col';
	label = document.createElement('label');
	label.htmlFor = 'dosage' + String(id);
	head = document.createElement('h4');
	head.innerText = 'dávkování';
	input = document.createElement('input');
	input.className = 'form-control fw-bold';
	input.id = 'dosage' + String(id);
	input.name = 'prescription[' + String(id) + '][dosage]';
	input.type = 'text';
	input.maxLength = '15';
	label.appendChild(head);
	col.appendChild(label);
	col.appendChild(input);
	row.appendChild(col);
	prescription.appendChild(row);

	document.getElementById('prescriptions').appendChild(prescription);

	if ( !id || String(id) === '9') {
		document.getElementById('add-prescription').style.display = 'none';	
	}
}

// SVG KEYDOWN EVENT

const svg = document.getElementById('svg');
svg.addEventListener('keydown', event => { add_prescription(); });

