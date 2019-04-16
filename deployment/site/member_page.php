<?php
session_start ();
if (isset($_SESSION['login']) && isset($_SESSION['pwd'])) {
	echo '<html>';
	echo '<head>';
	echo '<title>Your page</title>';
	echo '</head>';
	echo '<body>';
	echo '<p align="center">You successfully logged in!</p>';
	echo '<br />';
	echo '<p align="center">Your login is '.$_SESSION['login'].' and your password is '.$_SESSION['pwd'].'. </p>';
	echo '<br />';
	echo '<br />';
	echo '<p align="center"><!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
		<html>
		<img src="https://openclipart.org/image/800px/svg_to_png/197891/mono-logout.png" width="50" height="50" title="Logout" alt="Logo Logout" />

		</html>
		</p>';
echo '<form action="./logout.php" method="post">';
echo '<p align="center"><input type="submit" value="Logout"></p>';
echo '</form>';
}
else {
	echo 'Please log in.';
}
?>
