import jwt
import msgpack
import time
import platform
import statistics
import timeit
from datetime import datetime

MAX_HASH_SIZE = 256
HMAC_SECRET = 'Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg=='

COUNT_TO_RUN = 10
REQUESTS = 40_000

# --- дані ---
data = {
    "user_id": 414243,
    "role": 11,
    "devices": {
        "ios_expired_at": datetime.now().isoformat(),
        "android_expired_at": datetime.now().isoformat(),
        "external_api_integration_expired_at": datetime.now().isoformat()
    },
    "a": "a" * 100
}

# урізаємо поле a поки не влізе у 256 байт
while len(msgpack.packb(data)) > MAX_HASH_SIZE:
    data["a"] = data["a"][:-1]

# --- інформація про систему ---
os_name = platform.system()
os_version = platform.version()
cpu = platform.machine()
py_version = platform.python_version()

print(f"OS: {os_name} ({os_version})")
print(f"CPU: {cpu}")
print(f"Python version: {py_version}")
print(f"Hash bytesize: {len(msgpack.packb(data))}")

bench_marks_on_create = []
bench_marks_on_read = []

for _ in range(COUNT_TO_RUN):
    tokens = []

    print("\nChecking scale load...")
    print("when creates 40k tokens with Turbo Queue")

    # --- створення ---
    def create_tokens():
        for _ in range(REQUESTS):
            tokens.append(jwt.encode(data, HMAC_SECRET, algorithm="HS256"))

    t_create = timeit.timeit(create_tokens, number=1)
    bench_marks_on_create.append(round(t_create, 3))
    print(f"Create time: {t_create:.3f} sec")

    # --- читання ---
    def read_tokens():
        for tok in tokens:
            jwt.decode(tok, HMAC_SECRET, algorithms=["HS256"])

    t_read = timeit.timeit(read_tokens, number=1)
    bench_marks_on_read.append(round(t_read, 3))
    print(f"Read time: {t_read:.3f} sec")

# --- результати ---
print("\nOn Create")
print(f"Mediana: {statistics.median(bench_marks_on_create)}")
print(f"Min: {min(bench_marks_on_create)}")
print(f"Max: {max(bench_marks_on_create)}")

print("\nOn Read")
print(f"Mediana: {statistics.median(bench_marks_on_read)}")
print(f"Min: {min(bench_marks_on_read)}")
print(f"Max: {max(bench_marks_on_read)}")
