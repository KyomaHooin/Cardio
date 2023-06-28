<?php

try {
	$db = new SQlite3('../cardio.db');
} catch (Exception $e) {
	$db = null;
}

header("Cache-Control: no-store");
header("Content-Type: text/event-stream");

while (true) {

	$ret = array();

	if($db) {
		$result = $db->query("SELECT * FROM cardio;");
		if ($result->fetchArray()) {
			$result->reset();
			while ($res = $result->fetchArray(SQLITE3_ASSOC)) {
				array_push($ret, $res);
			}
		}
	}

	if ($ret) { echo 'data:' . json_encode($ret); }
	echo "\n\n";

	//ob_end_flush();
	flush();

	if (connection_aborted()) break;

	sleep(5);
}

?>

