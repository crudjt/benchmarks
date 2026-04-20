import org.msgpack.core.MessageBufferPacker;
import org.msgpack.core.MessagePack;

import java.util.HashMap;
import java.util.Map;
import java.util.TreeMap;
import java.util.concurrent.TimeUnit;
import java.util.TreeMap;
import java.time.Instant;

import java.util.ArrayList;
import java.util.List;

import java.io.IOException;

import java.util.Objects;

import java.util.Collections;

import com.crudjt.CRUDJT;

public class TestCRUDJT {
    public static final int COUNT_TO_RUN = 10;
    public static final int REQUESTS = 40_000;
    public static final int MAX_HASH_SIZE = 256;

    private static byte[] pack(Map<String, Object> map) throws IOException {
        MessageBufferPacker packer = MessagePack.newDefaultBufferPacker();
        packer.packMapHeader(map.size());
        for (Map.Entry<String, Object> entry : map.entrySet()) {
            packer.packString(entry.getKey());
            packer.packString(entry.getValue().toString());
        }
        packer.close();

        return packer.toByteArray();
    }

    public static void main(String[] args) throws IOException, InterruptedException {
        CRUDJT.Config.startMaster(
            Map.of(
                "secret_key", "Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg=="
            )
        );

        String os = System.getProperty("os.name").toLowerCase();
        String cpu = System.getProperty("os.arch");
        String version = System.getProperty("os.version");

        System.out.println("OS: " + os + " (" + version + ")");
        System.out.println("CPU: " + cpu);
        System.out.println("Java version: " + System.getProperty("java.version"));

        Map<String, Object> data = new HashMap<>();
        data.put("user_id", 414243);
        data.put("role", 11);
        data.put("devices", new HashMap<String, Object>() {{
            put("ios_expired_at", Instant.now().toString());
            put("android_expired_at", Instant.now().toString());
        }});
        data.put("a", "a".repeat(200));

        while (pack(data).length > MAX_HASH_SIZE) {
            String a = (String) data.get("a");
            data.put("a", a.substring(0, a.length() - 1));
        }

        System.out.println("Hash bytesize: " + pack(data).length);

        Map<String, Object> edData = new HashMap<>();
        edData.put("user_id", 42);
        edData.put("role", 8);


        List<Double> benchMarksOnCreate = new ArrayList<>();
        List<Double> benchMarksOnRead = new ArrayList<>();
        List<Double> benchMarksOnUpdate = new ArrayList<>();
        List<Double> benchMarksOnDelete = new ArrayList<>();

        for (int i = 0; i < COUNT_TO_RUN; i++) {
            long start, end;

            // when creates
            System.out.println("when creates 40k tokens");
            start = System.nanoTime();
            String[] tokens = new String[REQUESTS];
            for (int j = 0; j < REQUESTS; j++) {
                tokens[j] = CRUDJT.create(data, null, null);
            }
            end = System.nanoTime();

            double bench_on_create = (end - start) / 1e9;
            benchMarksOnCreate.add(bench_on_create);
            System.out.printf("Elapsed time: %.3f seconds\n", bench_on_create);

            // when reads
            System.out.println("when reads 40k tokens");
            start = System.nanoTime();
            for (int j = 0; j < REQUESTS; j++) {
                CRUDJT.read(tokens[j]);
            }
            end = System.nanoTime();

            double bench_on_read = (end - start) / 1e9;
            benchMarksOnRead.add(bench_on_read);
            System.out.printf("Elapsed time: %.3f seconds\n", bench_on_read);

            // when updates
            System.out.println("when updates 40k tokens");
            start = System.nanoTime();
            for (int j = 0; j < REQUESTS; j++) {
                CRUDJT.update(tokens[j], edData, null, null);
            }
            end = System.nanoTime();

            double bench_on_update = (end - start) / 1e9;
            benchMarksOnUpdate.add(bench_on_update);
            System.out.printf("Elapsed time: %.3f seconds\n", bench_on_update);

            // when deletes
            System.out.println("when deletes 40k tokens");
            start = System.nanoTime();
            for (int j = 0; j < REQUESTS; j++) {
                CRUDJT.delete(tokens[j]);
            }
            end = System.nanoTime();

            double bench_on_delete = (end - start) / 1e9;
            benchMarksOnDelete.add(bench_on_delete);
            System.out.printf("Elapsed time: %.3f seconds\n", bench_on_delete);
        }

        System.out.println();
        System.out.println("On Create");
        System.out.printf("Median: %.3f%n", benchMarksOnCreate.get((COUNT_TO_RUN - 1) / 2));
        System.out.printf("Min: %.3f%n", Collections.min(benchMarksOnCreate));
        System.out.printf("Max: %.3f%n", Collections.max(benchMarksOnCreate));

        System.out.println();
        System.out.println("On Read");
        System.out.printf("Median: %.3f%n", benchMarksOnRead.get((COUNT_TO_RUN - 1) / 2));
        System.out.printf("Min: %.3f%n", Collections.min(benchMarksOnRead));
        System.out.printf("Max: %.3f%n", Collections.max(benchMarksOnRead));

        System.out.println();
        System.out.println("On Update");
        System.out.printf("Median: %.3f%n", benchMarksOnUpdate.get((COUNT_TO_RUN - 1) / 2));
        System.out.printf("Min: %.3f%n", Collections.min(benchMarksOnUpdate));
        System.out.printf("Max: %.3f%n", Collections.max(benchMarksOnUpdate));

        System.out.println();
        System.out.println("On Delete");
        System.out.printf("Median: %.3f%n", benchMarksOnDelete.get((COUNT_TO_RUN - 1) / 2));
        System.out.printf("Min: %.3f%n", Collections.min(benchMarksOnDelete));
        System.out.printf("Max: %.3f%n", Collections.max(benchMarksOnDelete));
    }
}
