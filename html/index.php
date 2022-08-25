<?php

session_start();

?>

<!doctype html>
<html lang="cs">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>Kardiologie Řepy - Recepty</title>
	<link href="custom.css" rel="stylesheet">
	<!-- Favicons -->
	<link rel="apple-touch-icon" href="favicon/apple-touch-icon.png" sizes="180x180">
	<link rel="icon" href="favicon/favicon-32x32.png" sizes="32x32" type="image/png">
	<link rel="icon" href="favicon/favicon-16x16.png" sizes="16x16" type="image/png">
	<link rel="mask-icon" href="favicon/safari-pinned-tab.svg" color="#7952b3">
	<!-- Custom styles -->
	<link href="color.css" rel="stylesheet">
</head>

<body class="bg-light">

<div class="container-md">

<main>
<div class="row py-4 justify-content-center">
<div class="col-md-8">

<?php

if (isset($_POST['code'])) {
        if ($error) {
		echo '<div class="alert alert-warning alert-dismissible fade show" role="alert">' . $error . '<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button></div>';
        } elseif ($valid) {
		echo '<div class="alert alert-warning alert-dismissible fade show" role="alert">Hotovo. Děkujeme!<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button></div>';
        } else {
		echo '<div class="alert alert-warning alert-dismissible fade show" role="alert">Neplatný kontrolní kód.<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button></div>';
        }
}

?>

<div class="text-center m-4">
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" fill="currentColor" class="bi bi-capsule-pill" viewBox="0 0 16 16"><path fill-rule="evenodd" d="M11.02 5.364a3 3 0 0 0-4.242-4.243L1.121 6.778a3 3 0 1 0 4.243 4.243l5.657-5.657Zm-6.413-.657 2.878-2.879a2 2 0 1 1 2.829 2.829L7.435 7.536 4.607 4.707ZM12 8a4 4 0 1 1 0 8 4 4 0 0 1 0-8Zm-.5 1.041a3 3 0 0 0 0 5.918V9.04Zm1 5.918a3 3 0 0 0 0-5.918v5.918Z"/></svg>
</div>
<div class="p-4 text-center"><h2>Žádost vydání receptu</h2></div>

<div class="card"><div class="card-body" style="background-color: #cee5ed;">Formulář slouží k zaslání jednorázového požadavku na vydání předepsaného léčiva. Neslouží k objednání ani konzultaci Vašeho zdravotního stavu. Všechny požadavky jsou vyřizovány průběžně.</div></div>

<form method="post" action="." enctype="multipart/form-data">

<h4 class="mt-4">Jméno</h4>
<input type="text" class="form-control" id="firstname" name="firstname" placeholder="Pavel" value="" required>
<h4 class="mt-4">Příjmení</h4>
<input type="text" class="form-control" id="surname" name="surname" placeholder="Novák" value="" required>
<h4 class="mt-4">Rok narození</h4>
<input type="text" class="form-control" id="year" name="year" placeholder="1949" value="" required>

<div class="row g-3 row-cols-md-3 d-grid d-sm-flex">
	<div class="col">
		<h4 class="mt-4">Lék 1</h4>
		<input type="text" class="form-control" id="prescription1" name="prescription1" placeholder="Triplixam" value="" required>
	</div>
	<div class="col">
		<h4 class="mt-4">gramáž</h4>
		<input type="text" class="form-control" id="volume1" name="volume1" placeholder="5/1.25/5mg" value="" required>
	</div>
	<div class="col">
		<h4 class="mt-4">dávkování</h4>
		<input type="text" class="form-control" id="dosage1" name="dosage1" placeholder="1-0-1" value="" required>
	</div>
</div>

<div class="row g-3 row-cols-md-3 d-grid d-sm-flex">
	<div class="col">
		<h4 class="mt-4">Lék 2</h4>
		<input type="text" class="form-control" id="prescription2" name="prescription2" value="">
	</div>
	<div class="col">
		<h4 class="mt-4">gramáž</h4>
		<input type="text" class="form-control" id="volume2" name="volume2" value="">
	</div>
	<div class="col">
		<h4 class="mt-4">dávkování</h4>
		<input type="text" class="form-control" id="dosage2" name="dosage2" value="">
	</div>
</div>

<div class="row g-3 row-cols-md-3 d-grid d-sm-flex">
	<div class="col">
		<h4 class="mt-4">Lék 3</h4>
		<input type="text" class="form-control" id="prescription3" name="prescription3" value="">
	</div>
	<div class="col">
		<h4 class="mt-4">gramáž</h4>
		<input type="text" class="form-control" id="volume3" name="volume3" value="">
	</div>
	<div class="col">
		<h4 class="mt-4">dávkování</h4>
		<input type="text" class="form-control" id="dosage3" name="dosage3" value="">
	</div>
</div>

<div class="my-4">
<svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" fill="currentColor" class="bi bi-plus-square" viewBox="0 0 16 16"><path d="M14 1a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1h12zM2 0a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2H2z"/><path d="M8 4a.5.5 0 0 1 .5.5v3h3a.5.5 0 0 1 0 1h-3v3a.5.5 0 0 1-1 0v-3h-3a.5.5 0 0 1 0-1h3v-3A.5.5 0 0 1 8 4z"/></svg>
</div>

<div class="d-grid col-4 mx-auto my-4">
	<button type="submit" class="btn btn-primary">Odeslat</button>
</div>
</form>

<hr/>

</div>
</div>
</main>

<footer class="text-muted text-small text-center">
	<p>&copy; <?php echo date('Y');?> Kardiologie Praha 17 - Řepy s.r.o.</p>
	<ul class="list-inline">
		<li class="list-inline-item"><a class="link-primary" href="#">Nahoru</a></li>
	</ul>
</footer>

</div>

<script src="bootstrap.min.js"></script>

</body>
</html>

