<?php
  
session_start();

$error = '';

$db = null;

$db = new SQLite3('../cardio.db');

if (!$db) { $error = 'Chyba databáze.'; }

// XHR

$raw = file_get_contents('php://input');

if (preg_match('/drop:.*/', $raw)) {
	if ($db) {
		$drop = $db->exec("DELETE FROM cardio WHERE timestamp = '" . preg_replace('/drop:(.*)/','${1}', $raw) . "';");
		if ($drop) { echo 'ok'; }
	}
	exit();
}

?>

<!doctype html>
<html lang="cs">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>Kardiologie Řepy - Recepty</title>
	<link href="../custom.css" rel="stylesheet">
	<!-- Favicons -->
	<link rel="apple-touch-icon" href="../favicon/apple-touch-icon.png" sizes="180x180">
	<link rel="icon" href="../favicon/favicon-32x32.png" sizes="32x32" type="image/png">
	<link rel="icon" href="../favicon/favicon-16x16.png" sizes="16x16" type="image/png">
	<link rel="mask-icon" href="../favicon/safari-pinned-tab.svg" color="#7952b3">
	<!-- Custom styles -->
	<link href="../color.css" rel="stylesheet">
</head>

<body class="bg-light">

<nav class="navbar container-fluid navbar-expand-md navbar-dark" style="background-color: #0e5f91;">
	<div class="row align-items-center gx-0">
		<div class="col">
			<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="currentColor" class="bi bi-heart-pulse-fill" viewBox="0 0 16 16"><path fill-rule="evenodd" d="M1.475 9C2.702 10.84 4.779 12.871 8 15c3.221-2.129 5.298-4.16 6.525-6H12a.5.5 0 0 1-.464-.314l-1.457-3.642-1.598 5.593a.5.5 0 0 1-.945.049L5.889 6.568l-1.473 2.21A.5.5 0 0 1 4 9H1.475ZM.879 8C-2.426 1.68 4.41-2 7.824 1.143c.06.055.119.112.176.171a3.12 3.12 0 0 1 .176-.17C11.59-2 18.426 1.68 15.12 8h-2.783l-1.874-4.686a.5.5 0 0 0-.945.049L7.921 8.956 6.464 5.314a.5.5 0 0 0-.88-.091L3.732 8H.88Z"/></svg>
		</div>
		<div class="col"><a class="navbar-brand nav-link active" href="/cardio/">Kardio # Recepty</a></div>
	</div>
</nav>

<main class="container">
<div class="row my-4 justify-content-center">
<div class="col col-md-8 m-2">

<?php
	
	$data = $db->query("SELECT * FROM cardio ORDER BY timestamp;");
	$count = $db->querySingle("SELECT COUNT (timestamp) FROM cardio;");

	if ($count == 0) {
		echo '<div class="alert alert-warning alert-dismissible fade show" role="alert">Žádná data.<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button></div>';
	} else {
		echo '<table class="table">';
		echo '<thead class=""><tr><th scope="col">Datum</th><th scope="col">Jméno</th scope="col"><th>Rok</th><th scope="col">Recept</th><th></th></tr>';
		echo '</thead><tbody>';

		while ($row = $data->fetchArray(SQLITE3_ASSOC)) {
			echo '<tr id="' . $row['timestamp'] . '"><td>' . date("d.m.Y H:i", hexdec(substr($row['timestamp'],0,8))) . '</td>';
			echo '<td>' . $row['surname'] . ' ' . $row['firstname'] . '</td>';
			echo '<td>' . $row['year'] . '</td>';
			echo '<td>';

			foreach(unserialize($row['prescription']) as $prescription) {
				if (!empty($prescription['prescription'])) {
					echo '<div>' . $prescription['prescription'];
					if (!empty($prescription['volume'])) {	echo ' / ' . $prescription['volume']; }
					if (!empty($prescription['dosage'])) {	echo ' (' . $prescription['dosage'] . ')'; }
					echo '</div>';
				}
			}
			echo '</td>';
			echo '<td class="align-middle"><svg xmlns="http://www.w3.org/2000/svg" onclick="remove_prescription('
			. "'" . $row['timestamp'] . "'" . ')" width="24" height="24" fill="currentColor" class="bi bi-trash" viewBox="0 0 16 16"><path d="M5.5 5.5A.5.5 0 0 1 6 6v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm2.5 0a.5.5 0 0 1 .5.5v6a.5.5 0 0 1-1 0V6a.5.5 0 0 1 .5-.5zm3 .5a.5.5 0 0 0-1 0v6a.5.5 0 0 0 1 0V6z"/><path fill-rule="evenodd" d="M14.5 3a1 1 0 0 1-1 1H13v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V4h-.5a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1H6a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1h3.5a1 1 0 0 1 1 1v1zM4.118 4 4 4.059V13a1 1 0 0 0 1 1h6a1 1 0 0 0 1-1V4.059L11.882 4H4.118zM2.5 3V2h11v1h-11z"/></svg></td></tr>';
		}
		echo '</tbody></table>';
	}

	$db->close();

?>

</div>
</div>
</main>

<script src="../bootstrap.min.js"></script>
<script src="../custom.js"></script>

</body>
</html>

