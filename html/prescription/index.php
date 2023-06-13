<?php
  
session_start();

try {
	$db = new SQlite3('../cardio.db');
} catch (Exception $e) {
	$db = null;
}

if (!isset($_SESSION['result'])) { $_SESSION['result'] = null; }

if (!$db) { $_SESSION['result'] = 'Chyba čtení databáze.'; }

// XHR

if (json_decode(file_get_contents('php://input'))) {
	$req = json_decode(file_get_contents('php://input'), True);
	$resp = [];

	if ($req['type'] == 'remove') {
		$query = $db->exec("DELETE FROM cardio WHERE id = '" . $req['id'] . "';");
		if($query) {
			$resp['value'] = 'ok';
		}
	}
	
	if ($req['type'] == 'update') {
		$query = $db->exec("UPDATE cardio SET status = 1 WHERE id = '" . $req['id'] . "';");
		if($query) {
			$resp['value'] = 'ok';
		}
	}
	
	header('Content-Type: application/json; charset=utf-8');
	echo json_encode($resp);
	exit();
}

// POST

if (!empty($_POST)){
	if (isset($_POST['alert-text'])) {
		print_r($_POST);
		$query = $db->exec("REPLACE INTO alert(rowid,text) VALUES(1, '" . $_POST['alert-text'] . "');");
		if(!$query) {
			$_SESSION['result'] = "Zápis upozornění selhal.";
		} else {
			$_SESSION['result'] = "Upozornění uloženo."; 
		}
	}

	header('Location: /prescription/');
	exit();
}

?>

<!doctype html>
<html lang="cs">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>Kardiologie Praha 17 - Řepy</title>
	<link href="../custom.css" rel="stylesheet">
	<!-- Favicons -->
	<link rel="icon" href="../favicon/favicon-32x32.png" sizes="32x32" type="image/png">
	<link rel="icon" href="../favicon/favicon-16x16.png" sizes="16x16" type="image/png">
	<!-- Custom styles -->
	<link href="../color.css" rel="stylesheet">
</head>

<body class="bg-light">

<nav class="navbar container-fluid navbar-expand-md navbar-dark" style="background-color: #0e5f91;">
	<div class="row align-items-center gx-0">
		<div class="col">
			<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="currentColor" class="bi bi-heart-pulse-fill" viewBox="0 0 16 16"><path fill-rule="evenodd" d="M1.475 9C2.702 10.84 4.779 12.871 8 15c3.221-2.129 5.298-4.16 6.525-6H12a.5.5 0 0 1-.464-.314l-1.457-3.642-1.598 5.593a.5.5 0 0 1-.945.049L5.889 6.568l-1.473 2.21A.5.5 0 0 1 4 9H1.475ZM.879 8C-2.426 1.68 4.41-2 7.824 1.143c.06.055.119.112.176.171a3.12 3.12 0 0 1 .176-.17C11.59-2 18.426 1.68 15.12 8h-2.783l-1.874-4.686a.5.5 0 0 0-.945.049L7.921 8.956 6.464 5.314a.5.5 0 0 0-.88-.091L3.732 8H.88Z"/></svg>
		</div>
		<div class="col"><a class="navbar-brand nav-link active" href="/prescription/">Kardiologie Praha 17 - Řepy</a></div>
	</div>
</nav>

<main class="container">
<div class="row my-4 justify-content-center">
<div class="col col-md-8 m-2">

<?php 

if (isset($_SESSION['result'])) {
	echo '<div class="alert alert-warning alert-dismissible fade show" role="alert">'. $_SESSION['result'] . '<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button></div>';
	$_SESSION['result'] = null;
}

?>

<h4>Upozornění</h4>

<?php

if ($db) {
	$alert = $db->querySingle("SELECT text FROM alert;");
} else { $alert = null; }

?>

<form method="post" action="." enctype="multipart/form-data">
<table class="table table-borderless my-4">
	<tbody>
	<tr>
	<td class="col align-middle"><textarea class="form-control" id="alert-text" name="alert-text"><?php echo $alert;?></textarea></td>
	<td class="col-1 align-middle text-center">
		<input type="submit" id="alert-save" name="alert-save" value="alert-save" hidden>
		<svg xmlns="http://www.w3.org/2000/svg" onclick="alert_on_save()" width="24" height="24" fill="currentColor" class="bi bi-arrow-down-square" viewBox="0 0 16 16"><path fill-rule="evenodd" d="M15 2a1 1 0 0 0-1-1H2a1 1 0 0 0-1 1v12a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V2zM0 2a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V2zm8.5 2.5a.5.5 0 0 0-1 0v5.793L5.354 8.146a.5.5 0 1 0-.708.708l3 3a.5.5 0 0 0 .708 0l3-3a.5.5 0 0 0-.708-.708L8.5 10.293V4.5z"/></svg>	
	</td>
	</tr>
</tbody>
</table>
</form>

<h4>Recepty</h4>

<?php
	
	$result = $db->query("SELECT * FROM cardio ORDER BY timestamp DESC;");

	if ($result->fetchArray()) {
		$result->reset();
		
		echo '<table class="table">';
		echo '<thead class=""><tr><th scope="col">Datum</th><th scope="col">Jméno</th scope="col"><th>Rok</th><th scope="col">Recept</th><th></th><th></th></tr>';
		echo '</thead><tbody>';

		while ($res = $result->fetchArray(SQLITE3_ASSOC)) {
	
			if ($res['status']) { 
				echo '<tr id="' . $res['id'] . '" style="background-color: #fff3cd;">';
			} else {
				echo '<tr id="' . $res['id'] . '">';
			}

			echo '<td>' . date("d.m.Y H:i", hexdec(substr($res['timestamp'],0,8))) . '</td>';
			echo '<td>' . htmlspecialchars($res['surname']). ' ' . htmlspecialchars($res['firstname']). '</td>';
			echo '<td>' . htmlspecialchars($res['year']). '</td>';
			echo '<td class="align-middle">';

			foreach(unserialize($res['prescription']) as $prescription) {
				if (!empty($prescription['prescription'])) {
					echo '<div>' . htmlspecialchars($prescription['prescription']);
					if (!empty($prescription['volume'])) {	echo ' / ' . htmlspecialchars($prescription['volume']); }
					if (!empty($prescription['dosage'])) {	echo ' (' . htmlspecialchars($prescription['dosage']) . ')'; }
					echo '</div>';
				}
			}
			echo '</td>';
			echo '<td class="align-middle text-center"><button type="button" class="btn btn-sm btn-primary" style="background-color: #0e5f91;" onclick="prescription_on_update(' . "'" . $res['id'] . "'" . ')">Vydáno</button></td>';
			echo '<td class="align-middle"><svg xmlns="http://www.w3.org/2000/svg" onclick="prescription_on_remove('
			. "'" . $res['id'] . "'" . ')" width="24" height="24" fill="currentColor" class="bi bi-trash" viewBox="0 0 16 16"><path d="M5.5 5.5A.5.5 0 0 1 6 6v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm2.5 0a.5.5 0 0 1 .5.5v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm3 .5a.5.5 0 0 0-1 0v6a.5.5 0 0 0 1 0V6z"/><path fill-rule="evenodd" d="M14.5 3a1 1 0 0 1-1 1H13v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V4h-.5a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1H6a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1h3.5a1 1 0 0 1 1 1v1zM4.118 4 4 4.059V13a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1V4.059L11.882 4H4.118zM2.5 3V2h11v1h-11z"/></svg></td></tr>';
		}
		echo '</tbody></table>';
	} else {
		echo '<div class="alert alert-warning alert-dismissible fade show my-4" role="alert">Žádné recepty.<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button></div>';
	}

	$db->close();

?>

</div>
</div>
</main>

<div class="modal" id="modal" tabindex="-1">
	<div class="modal-dialog modal-dialog-centered">
	<div class="modal-content shadow">
		<div class="container-fluid">
			<div class="row my-2">
				<div class="col my-2">
					<span class="align-middle" id="modal-text">Opravdu chcete odstranit žádost?</span>
				</div>
				<div class="col-3 d-flex align-items-center">
					<button class="btn btn-sm btn-primary w-100" style="background-color: #0e5f91;" onclick="prescription_remove()">Ano</button>
				</div>
				<div class="col-1 d-flex align-items-center me-2">
					<button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
				</div>
			</div>
		</div>
	</div>
	</div>
</div>

<script src="../bootstrap.min.js"></script>
<script src="custom.js"></script>

</body>
</html>

