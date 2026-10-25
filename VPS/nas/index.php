<?php

try {
	$db = new SQlite3('../data/nas.db', SQLITE3_OPEN_READWRITE);
} catch (Exception $e) {
	$db = null;
}

date_default_timezone_set('CET');

if (array_key_exists('HTTP_X_NAS_I', apache_request_headers())) {
	if ($db) { $query = $db->exec("UPDATE nas SET ip = '" . $_SERVER['REMOTE_ADDR'] . "', last = '" . date('d.m.y H:i') . "' WHERE name = 'nas1';"); }
	exit();
}

if (array_key_exists('HTTP_X_NAS_II', apache_request_headers())) {
	if ($db) { $query = $db->exec("UPDATE nas SET ip = '" . $_SERVER['REMOTE_ADDR'] . "', last = '" . date('d.m.y H:i') . "' WHERE name = 'nas2';"); }
	exit();
}

if ($db) {
	$nas1 = $db->querySingle("SELECT ip FROM nas WHERE name = 'nas1';");
	$nas2 = $db->querySingle("SELECT ip FROM nas WHERE name = 'nas2';");
	$beacon1 = $db->querySingle("SELECT last FROM nas WHERE name = 'nas1';");
	$beacon2 = $db->querySingle("SELECT last FROM nas WHERE name = 'nas2';");
} else {
	$nas1 = 'neznámá adresa';
	$nas2 = 'neznámá adresa';
	$beacon1 = 'neznámý čas';
	$beacon2 = 'neznámý čas';
}

?>

<!doctype html>
<html lang="cs">
<head>
	<meta charset="utf-8">
	<meta name="robots" content="noindex">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>NAS IP</title>
	<link rel="icon" href="favicon/favicon-32x32.png" sizes="32x32" type="image/png">
	<link rel="icon" href="favicon/favicon-16x16.png" sizes="16x16" type="image/png">
	<link href="custom.css" rel="stylesheet">
</head>

<body style="background-color: #dee2e6;">

<main class="container">

<?php

if (!$db) {
	echo '<div class="row mt-4 m-2 d-flex align-items-center justify-content-center"><div class="alert text-center col col-md-5 alert-warning d-flex align-items-center" role="alert">Chyba čtení databáze.<button type="button" class="btn-close shadow-none ms-auto" data-bs-dismiss="alert" aria-label="Close"></button></div></div>';
}

?>

<div class="row mt-4 m-2 d-flex align-items-center justify-content-center">
<div class="col-5 col-md-2 bg-dark d-flex justify-content-center align-items-center"><div class="text-light fs-3">NAS I</div></div>
<div class="col-7 col-md-3 bg-light d-flex justify-content-center align-items-center"><div class="fs-3" id="nas1"><?php  echo htmlspecialchars($nas1); ?></div></div>
</div>

<div class="row m-2 d-flex align-items-center justify-content-center">
<div class="col-5 col-md-2 bg-dark d-flex justify-content-center align-items-center"><div class="text-light fs-3">NAS II</div></div>
<div class="col-7 col-md-3 bg-light d-flex justify-content-center align-items-center"><div class="fs-3" id="nas2"><?php  echo htmlspecialchars($nas2); ?></div></div>
</div>

<div class="row mt-4 mx-2 d-flex align-items-center justify-content-center">
<div class="col-5 col-md-2 d-flex justify-content-center align-items-center"><div class="fs-5 text-nowrap">Poslední odpověd:</div></div>
<div class="col-7 col-md-3 d-flex justify-content-center align-items-center"><div class="fs-5"><?php  echo htmlspecialchars($beacon1); ?></div></div>
</div>

<div class="row mx-2 d-flex align-items-center justify-content-center">
<div class="col-5 col-md-2 d-flex justify-content-center align-items-center"><div class="fs-5 text-nowrap">Poslední odpověd:</div></div>
<div class="col-7 col-md-3 d-flex justify-content-center align-items-center"><div class="fs-5"><?php  echo htmlspecialchars($beacon2); ?></div></div>
</div>

</main>
</body>
</html>
