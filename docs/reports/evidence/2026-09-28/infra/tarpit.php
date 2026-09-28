<?php
// Accepts SMTP connections and never answers (a hung or firewalled mail server).
$s = stream_socket_server('tcp://0.0.0.0:2525', $e, $m); $held = [];
while (true) { $c = @stream_socket_accept($s, 3600); if ($c) { $held[] = $c; fwrite(STDOUT, date('H:i:s')." accepted\n"); } }
