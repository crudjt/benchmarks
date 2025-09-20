import jwt from "jsonwebtoken";
import { encode as msgpackEncode } from "@msgpack/msgpack";
import os from "os";

const MAX_HASH_SIZE = 256;
const HMAC_SECRET =
  "Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg==";
const COUNT_TO_RUN = 10;
const REQUESTS = 40_000;

let data = {
  user_id: 414243,
  role: 11,
  devices: {
    ios_expired_at: new Date().toISOString(),
    android_expired_at: new Date().toISOString(),
    external_api_integration_expired_at: new Date().toISOString(),
  },
  a: "a".repeat(100),
};

while (Buffer.from(msgpackEncode(data)).length > MAX_HASH_SIZE) {
  data.a = data.a.slice(0, -1);
}

console.log(`OS: ${os.type()} ${os.release()}`);
console.log(`CPU: ${os.arch()}`);
console.log(`Node.js version: ${process.version}`);
console.log(`Hash bytesize: ${Buffer.from(msgpackEncode(data)).length}`);

const createTimes = [];
const readTimes = [];

for (let round = 0; round < COUNT_TO_RUN; round++) {
  const tokens = [];

  console.log("when creates 40k tokens");

  const t1 = performance.now();
  for (let i = 0; i < REQUESTS; i++) {
    const token = jwt.sign(data, HMAC_SECRET, { algorithm: "HS256" });
    tokens.push(token);
  }
  const t2 = performance.now();
  const createSec = (t2 - t1) / 1000;
  createTimes.push(createSec);
  console.log(`Create time: ${createSec.toFixed(3)} sec`);

  const t3 = performance.now();
  for (const tok of tokens) {
    jwt.verify(tok, HMAC_SECRET, { algorithms: ["HS256"] });
  }
  const t4 = performance.now();
  const readSec = (t4 - t3) / 1000;
  readTimes.push(readSec);
  console.log(`Read time: ${readSec.toFixed(3)} sec`);
}

console.log("\nOn Create");
printStats(createTimes);

console.log("\nOn Read");
printStats(readTimes);

function median(arr) {
  const sorted = [...arr].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 0
    ? (sorted[mid - 1] + sorted[mid]) / 2
    : sorted[mid];
}

function printStats(values) {
  const min = Math.min(...values);
  const max = Math.max(...values);
  const med = median(values);
  console.log(`Mediana: ${med.toFixed(3)}`);
  console.log(`Min: ${min.toFixed(3)}`);
  console.log(`Max: ${max.toFixed(3)}`);
}
