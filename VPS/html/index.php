<?php

session_start();

$timestamp = time();

function uuid(){
	$data = random_bytes(16);
	$data[6] = chr(ord($data[6]) & 0x0f | 0x40); 
	$data[8] = chr(ord($data[8]) & 0x3f | 0x80); 
	return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
}

function typo($text) {
	return preg_replace('/ ([aiuoksvzAIUOKSVZ]) /', ' $1&nbsp;', $text);
}

$id = uuid();

if (!isset($_SESSION['error'])) { $_SESSION['error'] = null; }

try {
	$db = new SQlite3('../data/cardio.db');
} catch (Exception $e) {
	$db = null;
}

$state = null; 
$title = null;
$alert = null;
$descr = null;

if (!isset($_SESSION['firstname'])) { $_SESSION['firstname'] = null; }
if (!isset($_SESSION['surname'])) { $_SESSION['surname'] = null; }
if (!isset($_SESSION['year'])) { $_SESSION['year'] = null; }

if ($db) { $state = $db->querySingle("SELECT state FROM offline;"); }
if ($db) { $title = $db->querySingle("SELECT text FROM title;"); }
if ($db) { $alert = $db->querySingle("SELECT text FROM alert;"); }
if ($db) { $descr = $db->querySingle("SELECT text FROM description;"); }

if(!empty($_POST)) {
	if (!($db and $state)) {
		$_SESSION['error'] = 'Požadavek nyní nelze přijmout.';
	} else {
		if (
			!empty($_POST['firstname']) &&
			!empty($_POST['surname']) &&
			!empty($_POST['year']) &&
			!empty($_POST['prescription'])
		) {
			$query = $db->exec("INSERT INTO cardio (id,status,confirmation,timestamp,firstname,surname,year,prescription) VALUES ('"
				. $id . "',0,0,"
				. $timestamp . ",'"
				. $db->escapeString(substr($_POST['firstname'],0,20)) . "','"
				. $db->escapeString(substr($_POST['surname'],0,20)) . "','"
				. $db->escapeString(substr($_POST['year'],0,4)) . "','"
				. $db->escapeString(serialize($_POST['prescription'])) . "');"
			);
			if (!$query) {
				$_SESSION['error'] = 'Chyba zápisu do databáze.';
			} else {
				$_SESSION['error'] = 'ok';
			}
			$_SESSION['firstname'] = $_POST['firstname'];
			$_SESSION['surname'] = $_POST['surname'];
			$_SESSION['year'] = $_POST['year'];
		} else {
			$_SESSION['error'] = 'Neplatný vstup.';
		}
	}
	$db->close();
	header('Location: /');
	exit();
}

?>

<!doctype html>
<html lang="cs">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>Kardiologie Praha 17 - Žádost</title>
	<link href="custom.css" rel="stylesheet">
	<!-- Favicons -->
	<link rel="icon" href="favicon/favicon-32x32.png" sizes="32x32" type="image/png">
	<link rel="icon" href="favicon/favicon-16x16.png" sizes="16x16" type="image/png">
	<!-- Custom styles -->
	<link href="color.css" rel="stylesheet">
</head>

<body class="bg-light">

<div class="container">

<main>
<div class="row py-4 px-1 justify-content-center">
<div class="col-md-10">

<?php

if (!empty($title)) {
	echo '<div class="p-4 text-center"><h2>' . typo($title) . '</h2></div>';
}

if (!empty($_SESSION['error'])) {
        if ($_SESSION['error'] !== 'ok') {
		echo '<div class="alert alert-danger fade show my-3 d-flex align-items-center" role="alert">' . $_SESSION['error'] . '<button type="button" class="btn-close btn-close-fix shadow-none ms-auto" data-bs-dismiss="alert" aria-label="Close"></button></div>';
        } else {
		echo '<div class="alert alert-success fade show my-3 d-flex align-items-center" role="alert">Žádost uložena. Děkujeme, že šetříte kapacitu naší telefonní linky.<button type="button" class="btn-close btn-close-fix shadow-none ms-auto" data-bs-dismiss="alert" aria-label="Close"></button></div>';
        }
	$_SESSION['error'] = null;
}

if (!empty($alert)) {
	echo '<div class="alert alert-warning d-flex align-items-center" role="alert">
	<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" fill="currentColor" class="bi bi-exclamation-triangle-fill flex-shrink-0 me-2" viewBox="0 0 16 16" role="img" aria-label="Warning:">
    <path d="M8.982 1.566a1.13 1.13 0 0 0-1.96 0L.165 13.233c-.457.778.091 1.767.98 1.767h13.713c.889 0 1.438-.99.98-1.767L8.982 1.566zM8 5c.535 0 .954.462.9.995l-.35 3.507a.552.552 0 0 1-1.1 0L7.1 5.995A.905.905 0 0 1 8 5zm.002 6a1 1 0 1 1 0 2 1 1 0 0 1 0-2z"/>
  </svg><div>' . typo(nl2br($alert)) . '</div></div>';
}

if (!empty($descr)) {
	echo '<div class="card"><div class="card-body" style="background-color: #cee5ed;">' . typo(nl2br($descr)) . '</div></div>';
}

?>

<form method="post" action="." enctype="multipart/form-data">
<fieldset <?php echo (!$state) ? 'disabled' : ''; ?>>

<h4 class="mt-4">Příjmení</h4>
<input type="text" class="form-control fw-bold" id="surname" name="surname" maxlength="20" value="<?php if (isset($_SESSION['surname'])) { echo htmlspecialchars($_SESSION['surname'], ENT_QUOTES, 'UTF-8'); } ?>" required>
<h4 class="mt-4">Jméno</h4>
<input type="text" class="form-control fw-bold" id="firstname" name="firstname" maxlength="20" value="<?php if (isset($_SESSION['firstname'])) { echo htmlspecialchars($_SESSION['firstname'], ENT_QUOTES, 'UTF-8'); } ?>" required>
<h4 class="mt-4">Rok narození</h4>
<input type="text" class="form-control fw-bold" id="year" name="year" maxlength="4" value="<?php if (isset($_SESSION['year'])) { echo htmlspecialchars($_SESSION['year'], ENT_QUOTES, 'UTF-8'); } ?>" required>

<hr/>

<div id="prescriptions">
<div class="row align-items-end g-3 row-cols-md-3 d-grid d-sm-flex">
	<div class="col">
		<span class="h4">Lék 1</span>
		<input type="text" class="form-control fw-bold mt-2" id="prescription0" name="prescription[0][prescription]" maxlength="25" value="" required>
	</div>
	<div class="col">
		<span class="h4">gramáž</span><span class="ms-2">(např. 10mg, 5/1.25mg)</span>
		<input type="text" class="form-control fw-bold mt-2" id="volume0" name="prescription[0][volume]" maxlength="15" value="" required>
	</div>
	<div class="col">
		<span class="h4">dávkování</span><span class="ms-2">(např. 1-0-1)</span>
		<input type="text" class="form-control fw-bold mt-2" id="dosage0" name="prescription[0][dosage]" maxlength="15" value="" required>
	</div>
</div>
<hr/>
<div class="row g-3 row-cols-md-3 d-grid d-sm-flex">
	<div class="col">
		<h4>Lék 2</h4>
		<input type="text" class="form-control fw-bold" id="prescription1" maxlength="25" name="prescription[1][prescription]" value="">
	</div>
	<div class="col">
		<h4>gramáž</h4>
		<input type="text" class="form-control fw-bold" id="volume1" maxlength="15" name="prescription[1][volume]" value="">
	</div>
	<div class="col">
		<h4>dávkování</h4>
		<input type="text" class="form-control fw-bold" id="dosage1" maxlength="15" name="prescription[1][dosage]" value="">
	</div>
</div>
<hr/>
<div class="row g-3 row-cols-md-3 d-grid d-sm-flex">
	<div class="col">
		<h4>Lék 3</h4>
		<input type="text" class="form-control fw-bold" id="prescription2" maxlength="25" name="prescription[2][prescription]" value="">
	</div>
	<div class="col">
		<h4>gramáž</h4>
		<input type="text" class="form-control fw-bold" id="volume2" maxlength="15" name="prescription[2][volume]" value="">
	</div>
	<div class="col">
		<h4>dávkování</h4>
		<input type="text" class="form-control fw-bold" id="dosage2" maxlength="15" name="prescription[2][dosage]" value="">
	</div>
</div>
</div>

<div id="add-prescription" class="my-4">
<svg xmlns="http://www.w3.org/2000/svg" onclick="add_prescription()" width="36" height="36" fill="currentColor" class="bi bi-plus-square" viewBox="0 0 16 16"><path d="M14 1a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1V2a1 1 0 0 1 1-1h12zM2 0a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V2a2 2 0 0 0-2-2H2z"/><path d="M8 4a.5.5 0 0 1 .5.5v3h3a.5.5 0 0 1 0 1h-3v3a.5.5 0 0 1-1 0v-3h-3a.5.5 0 0 1 0-1h3v-3A.5.5 0 0 1 8 4z"/></svg><span class="ms-2">(přidat další lék)</span>
</div>

<div class="d-grid col-4 mx-auto my-4">
	<button type="submit" name="submit" class="btn btn-primary" style="background-color: #0e5f91;">Odeslat</button>
</div>

</fieldset>
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
<script src="custom.js"></script>

</body>
</html>

