<?php

try {
	$db = new SQlite3('../data/nas.db', SQLITE3_OPEN_READWRITE);
} catch (Exception $e) {
	$db = null;
}

date_default_timezone_set('CET');

$headers = apache_request_headers();

if (array_key_exists('HTTP_X_NAS_I', $headers)) {
	if ($db) { $query = $db->exec("UPDATE nas SET ip = '" . $_SERVER['REMOTE_ADDR'] . "', last = '" . date('d.m.y H:i') . "' WHERE name = 'nas1';"); }
	if (array_key_exists('HTTP_X_NAS_I_LOCK', $headers)) {
		if ($db) { $query = $db->exec("UPDATE nas SET lock = '" . $db->escapeString($headers['HTTP_X_NAS_I_LOCK']) . "' WHERE name = 'nas1';"); }
	}
	exit();
}

if (array_key_exists('HTTP_X_NAS_II', $headers)) {
	if ($db) { $query = $db->exec("UPDATE nas SET ip = '" . $_SERVER['REMOTE_ADDR'] . "', last = '" . date('d.m.y H:i') . "' WHERE name = 'nas2';"); }
	if (array_key_exists('HTTP_X_NAS_II_LOCK', $headers)) {
		if ($db) { $query = $db->exec("UPDATE nas SET lock = '" . $db->escapeString($headers['HTTP_X_NAS_II_LOCK']) . "' WHERE name = 'nas2';"); }
	}
	exit();
}

if ($db) {
	$nas1 = $db->querySingle("SELECT ip FROM nas WHERE name = 'nas1';");
	$nas2 = $db->querySingle("SELECT ip FROM nas WHERE name = 'nas2';");
	$beacon1 = $db->querySingle("SELECT last FROM nas WHERE name = 'nas1';");
	$beacon2 = $db->querySingle("SELECT last FROM nas WHERE name = 'nas2';");
	$lock1 = $db->querySingle("SELECT lock FROM nas WHERE name = 'nas1';");
	$lock2 = $db->querySingle("SELECT lock FROM nas WHERE name = 'nas2';");
} else {
	$nas1 = 'neznámá adresa';
	$nas2 = 'neznámá adresa';
	$beacon1 = 'neznámý čas';
	$beacon2 = 'neznámý čas';
	$lock1 = 0;
	$lock2 = 0;
}

?>

<!doctype html>
<html lang="cs">
<head>
	<meta charset="utf-8">
	<meta name="robots" content="noindex">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>Kardiologie Praha 17 - Řepy</title>
	<link rel="icon" href="favicon/favicon-32x32.png" sizes="32x32" type="image/png">
	<link rel="icon" href="favicon/favicon-16x16.png" sizes="16x16" type="image/png">
	<link href="custom.css" rel="stylesheet">
</head>

<body style="background-color: #dee2e6;">

<nav class="navbar container-fluid navbar-expand-md navbar-dark" style="background-color: #0e5f91;">
	<div class="row align-items-center gx-0">
		<div class="col">
			<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="currentColor" class="bi bi-heart-pulse-fill" viewBox="0 0 16 16"><path fill-rule="evenodd" d="M1.475 9C2.702 10.84 4.779 12.871 8 15c3.221-2.129 5.298-4.16 6.525-6H12a.5.5 0 0 1-.464-.314l-1.457-3.642-1.598 5.593a.5.5 0 0 1-.945.049L5.889 6.568l-1.473 2.21A.5.5 0 0 1 4 9H1.475ZM.879 8C-2.426 1.68 4.41-2 7.824 1.143c.06.055.119.112.176.171a3.12 3.12 0 0 1 .176-.17C11.59-2 18.426 1.68 15.12 8h-2.783l-1.874-4.686a.5.5 0 0 0-.945.049L7.921 8.956 6.464 5.314a.5.5 0 0 0-.88-.091L3.732 8H.88Z"/></svg>
		</div>
		<div class="col"><a class="navbar-brand nav-link active" href="/">Kardiologie Praha 17 - Řepy</a></div>
	</div>
</nav>

<main class="container">

<?php

if (!$db) {
	echo '<div class="row mt-4 m-2 d-flex align-items-center justify-content-center"><div class="alert text-center col col-md-6 alert-warning d-flex align-items-center" role="alert">Chyba čtení databáze.<button type="button" class="btn-close shadow-none ms-auto" data-bs-dismiss="alert" aria-label="Close"></button></div></div>';
}

?>


<div class="row mt-4 m-2 d-flex align-items-center justify-content-center">

<div class="col-3 col-xl-2 bg-dark d-flex justify-content-center align-items-center"><div class="text-light text-nowrap fs-3">NAS I</div></div>
<div class="col-7 col-xl-3 bg-light d-flex justify-content-center align-items-center"><div class="fs-3 text-nowrap" id="nas1"><?php  echo htmlspecialchars($nas1); ?></div></div>
<div class="col-2 col-xl-1 d-flex justify-content-start align-items-center">
<?php
	if ($lock1) {
	echo '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="#198754" class="bi bi-unlock2-fill" viewBox="0 0 16 16"><path fill-rule="evenodd" d="M8 0c1.07 0 2.041.42 2.759 1.104l.14.14.062.08a.5.5 0 0 1-.71.675l-.076-.066-.216-.205A3 3 0 0 0 5 4v2h6.5A2.5 2.5 0 0 1 14 8.5v5a2.5 2.5 0 0 1-2.5 2.5h-7A2.5 2.5 0 0 1 2 13.5v-5a2.5 2.5 0 0 1 2-2.45V4a4 4 0 0 1 4-4"/></svg>';
	} else {
	echo '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="#dc3545" class="bi bi-lock-fill" viewBox="0 0 16 16"><path fill-rule="evenodd" d="M8 0a4 4 0 0 1 4 4v2.05a2.5 2.5 0 0 1 2 2.45v5a2.5 2.5 0 0 1-2.5 2.5h-7A2.5 2.5 0 0 1 2 13.5v-5a2.5 2.5 0 0 1 2-2.45V4a4 4 0 0 1 4-4m0 1a3 3 0 0 0-3 3v2h6V4a3 3 0 0 0-3-3"/></svg>';
	}
?>
</div>
</div>

<div class="row m-2 d-flex align-items-center justify-content-center">

<div class="col-3 col-xl-2 bg-dark d-flex justify-content-center align-items-center"><div class="text-light text-nowrap fs-3">NAS II</div></div>
<div class="col-7 col-xl-3 bg-light d-flex justify-content-center align-items-center"><div class="fs-3 text-nowrap" id="nas2"><?php  echo htmlspecialchars($nas2); ?></div></div>
<div class="col-2 col-xl-1 d-flex justify-content-start align-items-center">
<?php
	if ($lock2) {
	echo '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="#198754" class="bi bi-unlock2-fill" viewBox="0 0 16 16"><path fill-rule="evenodd" d="M8 0c1.07 0 2.041.42 2.759 1.104l.14.14.062.08a.5.5 0 0 1-.71.675l-.076-.066-.216-.205A3 3 0 0 0 5 4v2h6.5A2.5 2.5 0 0 1 14 8.5v5a2.5 2.5 0 0 1-2.5 2.5h-7A2.5 2.5 0 0 1 2 13.5v-5a2.5 2.5 0 0 1 2-2.45V4a4 4 0 0 1 4-4"/></svg>';
	} else {
	echo '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" fill="#dc3545" class="bi bi-lock-fill" viewBox="0 0 16 16"><path fill-rule="evenodd" d="M8 0a4 4 0 0 1 4 4v2.05a2.5 2.5 0 0 1 2 2.45v5a2.5 2.5 0 0 1-2.5 2.5h-7A2.5 2.5 0 0 1 2 13.5v-5a2.5 2.5 0 0 1 2-2.45V4a4 4 0 0 1 4-4m0 1a3 3 0 0 0-3 3v2h6V4a3 3 0 0 0-3-3"/></svg>';
	}
?>
</div>
</div>

<div class="row mt-4 mx-2 d-flex align-items-center justify-content-center">
<div class="col-6 col-xl-2 d-flex justify-content-center align-items-center"><div class="fs-5 text-nowrap">Poslední odpověd:</div></div>
<div class="col-6 col-xl-2 d-flex justify-content-start align-items-center"><div class="fs-5 text-nowrap"><?php  echo htmlspecialchars($beacon1); ?></div></div>
</div>

<div class="row mx-2 d-flex align-items-center justify-content-center">
<div class="col-6 col-xl-2 d-flex justify-content-center align-items-center"><div class="fs-5 text-nowrap">Poslední odpověd:</div></div>
<div class="col-6 col-xl-2 d-flex justify-content-start align-items-center"><div class="fs-5 text-nowrap"><?php  echo htmlspecialchars($beacon2); ?></div></div>
</div>

</main>
</body>
</html>
