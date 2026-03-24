import time
import json
import random
import platform
import subprocess
import sys
import msgpack

import crudjt

CRUDJT.Config.start_master(
  secret_key='Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittlOHR2dciYiwmaYq98l3tG8h9yXVCxg=='
)

os_name = platform.system().lower()
cpu = platform.machine()

if "darwin" in os_name or "mac" in os_name:
    version = subprocess.check_output(["sw_vers", "-productVersion"]).decode().strip()
elif "linux" in os_name:
    version = subprocess.check_output(["uname", "-r"]).decode().strip()
elif "windows" in os_name:
    version = subprocess.check_output(["ver"], shell=True).decode().strip()
else:
    version = "unknown"

print(f"OS: {os_name} ({version})")
print(f"CPU: {cpu}")
print(f"Python version: {platform.python_version()}")

MAX_HASH_SIZE = 256
COUNT_TO_RUN = 10
REQUESTS = 40_000

data = {
    "user_id": 414243,
    "role": 11,
    "devices": {
        "ios_expired_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "android_expired_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "external_api_integration_expired_at": time.strftime("%Y-%m-%d %H:%M:%S"),
    },
    "a": "a" * 100,
}

while len(msgpack.packb(data)) > MAX_HASH_SIZE:
    data["a"] = data["a"][:-1]

packed = msgpack.packb(data)

updated_data = {'user_id': 42, 'role': 11}

print(f"Hash bytesize: {len(packed)}")


bench_marks_on_create = []
bench_marks_on_read = []
bench_marks_on_update = []
bench_marks_on_delete = []

rounding = 3

for _ in range(COUNT_TO_RUN):
    tokens = []

    print('when creates 40k tokens')
    start_time = time.time()
    for i in range(REQUESTS):
        tokens.append(CRUDJT.create(data))
    bench_on_create = round(time.time() - start_time, rounding)
    print(f"{bench_on_create}")
    bench_marks_on_create.append(bench_on_create)

    print('when reads 40k tokens')
    start_time = time.time()
    for i in range(REQUESTS):
        CRUDJT.read(tokens[i])
    bench_on_read = round(time.time() - start_time, rounding)
    print(f"{bench_on_read}")
    bench_marks_on_read.append(bench_on_read)

    print('when updates 40k tokens')
    start_time = time.time()
    for i in range(REQUESTS):
        CRUDJT.update(tokens[i], updated_data)
    bench_on_update = round(time.time() - start_time, rounding)
    print(f"{bench_on_update}")
    bench_marks_on_update.append(bench_on_update)

    print('when deletes 40k tokens')
    start_time = time.time()
    for i in range(REQUESTS):
        CRUDJT.delete(tokens[i])
    bench_on_delete = round(time.time() - start_time, rounding)
    print(f"{bench_on_delete}")
    bench_marks_on_delete.append(bench_on_delete)

print()

print('On Create')
print(f"Mediana: {bench_marks_on_create[(COUNT_TO_RUN - 1) // 2]}")
print(f"Min: {min(bench_marks_on_create)}")
print(f"Max: {max(bench_marks_on_create)}")

print()

print('On Read')
print(f"Mediana: {bench_marks_on_read[(COUNT_TO_RUN - 1) // 2]}")
print(f"Min: {min(bench_marks_on_read)}")
print(f"Max: {max(bench_marks_on_read)}")

print()

print('On Update')
print(f"Mediana: {bench_marks_on_update[(COUNT_TO_RUN - 1) // 2]}")
print(f"Min: {min(bench_marks_on_update)}")
print(f"Max: {max(bench_marks_on_update)}")

print()

print('On Delete')
print(f"Mediana: {bench_marks_on_delete[(COUNT_TO_RUN - 1) // 2]}")
print(f"Min: {min(bench_marks_on_delete)}")
print(f"Max: {max(bench_marks_on_delete)}")
