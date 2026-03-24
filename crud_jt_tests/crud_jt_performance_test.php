<?php

require __DIR__ . '/vendor/autoload.php';

use CRUDJT\CRUDJT;

\CRUDJT\Config::startMaster([
  'secret_key' => "Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg=="
]);

$os = PHP_OS_FAMILY;
$cpu = php_uname('m');
switch (strtolower($os)) {
    case 'darwin':
        $version = trim(shell_exec('sw_vers -productVersion')) ?: 'unknown';
        break;
    case 'linux':
        $version = trim(shell_exec('uname -r')) ?: 'unknown';
        break;
    default:
        $version = 'unknown';
}
echo "OS: $os ($version)" . PHP_EOL;
echo "CPU: $cpu" . PHP_EOL;
echo "PHP version: " . PHP_VERSION . PHP_EOL;

const COUNT_TO_RUN = 10;
const REQUESTS = 40_000;
const MAX_HASH_SIZE = 256;

$data = [
    'user_id' => 414243,
    'role' => 11,
    'devices' => [
        'ios_expired_at' => date('c'),
        'android_expired_at' => date('c'),
    ],
    'a' => str_repeat('a', 1000)
];

while (strlen(msgpack_pack($data)) > MAX_HASH_SIZE) {
    $data['a'] = substr($data['a'], 0, -1);
}

$updated = ['user_id' => 42, 'role' => 11];

$packed = msgpack_pack($data);
echo "Hash bytesize: " . strlen($packed) . PHP_EOL;

$benchCreate = [];
$benchRead = [];
$benchUpdate = [];
$benchDelete = [];

for ($round = 0; $round < COUNT_TO_RUN; $round++) {
    $tokens = [];

    // Create
    echo "when creates 40k tokens" . PHP_EOL;
    $start = microtime(true);
    for ($i = 0; $i < REQUESTS; $i++) {
        $tokens[] = CRUDJT::create($data);
    }
    $elapsed = round(microtime(true) - $start, 3);
    $benchCreate[] = $elapsed;
    echo "$elapsed sec" . PHP_EOL;

    // Read
    echo "when reads 40k tokens" . PHP_EOL;
    $start = microtime(true);
    for ($i = 0; $i < REQUESTS; $i++) {
        CRUDJT::read($tokens[$i]);
    }
    $elapsed = round(microtime(true) - $start, 3);
    $benchRead[] = $elapsed;
    echo "$elapsed sec" . PHP_EOL;

    // Update
    echo "when updates 40k tokens" . PHP_EOL;
    $start = microtime(true);
    for ($i = 0; $i < REQUESTS; $i++) {
        CRUDJT::update($tokens[$i], $updated);
    }
    $elapsed = round(microtime(true) - $start, 3);
    $benchUpdate[] = $elapsed;
    echo "$elapsed sec" . PHP_EOL;

    // Delete
    echo "when deletes 40k tokens" . PHP_EOL;
    $start = microtime(true);
    for ($i = 0; $i < REQUESTS; $i++) {
        CRUDJT::delete($tokens[$i]);
    }
    $elapsed = round(microtime(true) - $start, 3);
    $benchDelete[] = $elapsed;
    echo "$elapsed sec" . PHP_EOL;
}

// --- Results ---
function report($label, $arr) {
    sort($arr);
    $median = $arr[(int) floor((COUNT_TO_RUN - 1) / 2)];
    printf(
        "\n%s\nMediana: %.3f\nMin: %.3f\nMax: %.3f\n",
        $label, $median, min($arr), max($arr)
    );
}

report('On Create', $benchCreate);
report('On Read', $benchRead);
report('On Update', $benchUpdate);
report('On Delete', $benchDelete);
