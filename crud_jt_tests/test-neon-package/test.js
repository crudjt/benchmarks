const CRUDJT = require('crudjt');
const { performance } = require("perf_hooks");
const os = require("os");
const msgpack = require('msgpack-lite');

const COUNT_TO_RUN = 10;
const REQUESTS = 40_000;
const MAX_HASH_SIZE = 256;

// Asynchronous function for time measurement
async function benchmarkAsync(fn) {
  const start = performance.now();
  await fn();
  const end = performance.now();
  return ((end - start) / 1000).toFixed(3); // seconds
}

// Function to calculate the median
function median(arr) {
  return arr[Math.floor((arr.length - 1) / 2)];
}

async function main() {
  await CRUDJT.Config.startMaster({
    secret_key: "Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg=="
  });

  console.log(`OS: ${process.platform} (${os.release()})`);
  console.log(`CPU: ${os.arch()}`);
  console.log(`Node version: ${process.version}`);

  // Data preparation
  let data = {
    user_id: 414243,
    role: 11,
    devices: {
      ios_expired_at: new Date().toString(),
      android_expired_at: new Date().toString(),
    },
    a: "a".repeat(100),
  };

  while (msgpack.encode(data).length > MAX_HASH_SIZE) {
    data.a = data.a.slice(0, -1);
  }

  const updatedData = { user_id: 42, role: 11 };
  console.log(`Hash bytesize: ${msgpack.encode(data).length}`);

  // Arrays for benchmark results
  let benchMarksOnCreate = [];
  let benchMarksOnRead = [];
  let benchMarksOnUpdate = [];
  let benchMarksOnDelete = [];

  for (let j = 0; j < COUNT_TO_RUN; j++) {
    let tokens = [];
    console.log(`\nIteration ${j + 1}/${COUNT_TO_RUN}`);
    console.log("Checking scale load...");

    // Create
    console.log("when creates 40k tokens");
    let time = await benchmarkAsync(async () => {
      for (let i = 0; i < REQUESTS; i++) {
        tokens.push(await CRUDJT.create(data));
      }
    });
    benchMarksOnCreate.push(parseFloat(time));
    console.log(`Elapsed time: ${time}`);

    // Read
    console.log("when reads 40k tokens");
    time = await benchmarkAsync(async () => {
      for (let i = 0; i < REQUESTS; i++) {
        await CRUDJT.read(tokens[i]);
      }
    });
    benchMarksOnRead.push(parseFloat(time));
    console.log(`Elapsed time: ${time}`);

    // Update
    console.log("when updates 40k tokens");
    time = await benchmarkAsync(async () => {
      for (let i = 0; i < REQUESTS; i++) {
        await CRUDJT.update(tokens[i], updatedData);
      }
    });
    benchMarksOnUpdate.push(parseFloat(time));
    console.log(`Elapsed time: ${time}`);

    // Delete
    console.log("when deletes 40k tokens");
    time = await benchmarkAsync(async () => {
      for (let i = 0; i < REQUESTS; i++) {
        await CRUDJT.delete(tokens[i]);
      }
    });
    benchMarksOnDelete.push(parseFloat(time));
    console.log(`Elapsed time: ${time}`);
  }

  // Statistics output
  console.log("\nOn Create");
  console.log(`Mediana: ${median(benchMarksOnCreate)}`);
  console.log(`Min: ${Math.min(...benchMarksOnCreate)}`);
  console.log(`Max: ${Math.max(...benchMarksOnCreate)}`);

  console.log("\nOn Read");
  console.log(`Mediana: ${median(benchMarksOnRead)}`);
  console.log(`Min: ${Math.min(...benchMarksOnRead)}`);
  console.log(`Max: ${Math.max(...benchMarksOnRead)}`);

  console.log("\nOn Update");
  console.log(`Mediana: ${median(benchMarksOnUpdate)}`);
  console.log(`Min: ${Math.min(...benchMarksOnUpdate)}`);
  console.log(`Max: ${Math.max(...benchMarksOnUpdate)}`);

  console.log("\nOn Delete");
  console.log(`Mediana: ${median(benchMarksOnDelete)}`);
  console.log(`Min: ${Math.min(...benchMarksOnDelete)}`);
  console.log(`Max: ${Math.max(...benchMarksOnDelete)}`);

  // Closing the gRPC server master
  await CRUDJT.Config.shutdownServer();
}

main().catch(console.error);
