<?php
$login_valid = "roger";
$pwd_valid = "roger";
if (isset($_POST['login']) && isset($_POST['pwd'])) {
	if ($login_valid == $_POST['login'] && $pwd_valid == $_POST['pwd']) {
		session_start ();
		$_SESSION['login'] = $_POST['login'];
		$_SESSION['pwd'] = $_POST['pwd'];
		header ('location: member_page.php');
	}
	else {
		echo '<body onLoad="alert(\'Member unknown...\')">';
		echo '<meta http-equiv="refresh" content="0;URL=index.html">';
	}
}
else {
	echo 'Please refresh';
}
?>
