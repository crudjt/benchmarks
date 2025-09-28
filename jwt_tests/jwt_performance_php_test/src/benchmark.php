#!/usr/bin/env php
<?php
require __DIR__ . '/../vendor/autoload.php';

use Firebase\JWT\JWT;
use Firebase\JWT\Key;

const MAX_HASH_SIZE = 256;
const HMAC_SECRET = "Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg==";
const ALG = 'HS256';
const REQUESTS = 40000;
const ROUNDS = 10;

/* -------- OS + PHP info -------- */
$osFamily = PHP_OS_FAMILY; // e.g. "Darwin", "Linux"
$osName = php_uname('s'); // e.g. "Darwin"
$osVersion = php_uname('r'); // kernel version
printf("OS: %s (%s) version %s\n", $osFamily, $osName, $osVersion);
printf("PHP: %s\n", PHP_VERSION);

/* -------- Initial data -------- */
$isoNow = gmdate('Y-m-d\TH:i:s\Z');
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

/* -------- Ensure max hash size -------- */
printf("Hash bytesize: %d\n", strlen(msgpack_pack($data)));

/* -------- Benchmark -------- */
runBenchmarks(ROUNDS, REQUESTS, $data);

/* ================= FUNCTIONS ================= */

function runBenchmarks(int $rounds, int $requests, array $data): void {
    $createTimes = [];
    $verifyTimes = [];

    for ($i = 1; $i <= $rounds; $i++) {
        echo "\n=== Round $i ===\n";

        // ---- Create ----
        $start = microtime(true);
        $tokens = [];
        for ($j = 0; $j < $requests; $j++) {
            $tokens[] = createJWT($data);
        }
        $createSec = microtime(true) - $start;
        printf("Create time for %d tokens: %.3f sec\n", $requests, $createSec);
        $createTimes[] = $createSec;

        // ---- Verify ----
        $start = microtime(true);
        foreach ($tokens as $t) {
            verifyJWT($t);
        }
        $verifySec = microtime(true) - $start;
        printf("Read time for %d tokens: %.3f sec\n", $requests, $verifySec);
        $verifyTimes[] = $verifySec;
    }

    printStats("On Create", $createTimes);
    printStats("On Read", $verifyTimes);
}

function createJWT(array $data): string {
    return JWT::encode($data, HMAC_SECRET, ALG);
}

function verifyJWT(string $token): array {
    return (array) JWT::decode($token, new Key(HMAC_SECRET, ALG));
}

function printStats(string $label, array $times): void {
    sort($times);
    $len = count($times);
    $median = ($len % 2)
        ? $times[intdiv($len,2)]
        : ($times[$len/2 - 1] + $times[$len/2]) / 2;
    printf("\n%s\nMediana: %.3f\nMin: %.3f\nMax: %.3f\n",
        $label, $median, min($times), max($times));
}
