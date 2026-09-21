<?php

if (in_array('HTTP_X_NASI', apache_request_headers()) {
	file_put_contents('/var/www/nas/nas1.txt', $_SERVER['REMOTE_ADDR']);
	exit();
}

if (in_array('HTTP_X_NASII', apache_request_headers()) {
	file_put_contents('/var/www/nas/nas2.txt', $_SERVER['REMOTE_ADDR']);
	exit();
}

$nas1 = file_get_contents('/var/www/nas/nas1.txt');
$nas2 = file_get_contents('/var/www/nas/nas2.txt');

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

<div class="row mt-4 m-2 d-flex align-items-center justify-content-center">
<div class="col-5 col-md-2 bg-dark d-flex justify-content-center align-items-center"><div class="text-light fs-3">NAS I</div></div>
<div class="col-7 col-md-3 bg-light d-flex justify-content-center align-items-center"><div class="fs-3" id="nas1"><?php  echo htmlspecialchars($nas1); ?></div></div>
</div>

<div class="row m-2 d-flex align-items-center justify-content-center">
<div class="col-5 col-md-2 bg-dark d-flex justify-content-center align-items-center"><div class="text-light fs-3">NAS II</div></div>
<div class="col-7 col-md-3 bg-light d-flex justify-content-center align-items-center"><div class="fs-3" id="nas2"><?php  echo htmlspecialchars($nas2); ?></div></div>
</div>

</main>
</body>
</html>
