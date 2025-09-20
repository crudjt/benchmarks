package org.example;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import org.msgpack.core.MessageBufferPacker;
import org.msgpack.core.MessagePack;
import org.msgpack.core.MessagePacker;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.*;

public class App {

    static final int MAX_HASH_SIZE = 256;
    static final String HMAC_SECRET =
            "Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg==";
    static final int COUNT_TO_RUN = 10;
    static final int REQUESTS = 40_000;

    public static void main(String[] args) throws Exception {
        Map<String, Object> devices = new HashMap<>();
        devices.put("ios_expired_at", Instant.now().toString());
        devices.put("android_expired_at", Instant.now().toString());
        devices.put("external_api_integration_expired_at", Instant.now().toString());

        Map<String, Object> data = new HashMap<>();
        data.put("user_id", 414243);
        data.put("role", 11);
        data.put("devices", devices);
        data.put("a", "a".repeat(100));

        while (packedSize(data) > MAX_HASH_SIZE) {
            String a = (String) data.get("a");
            data.put("a", a.substring(0, a.length() - 1));
        }

        System.out.printf("OS: %s (%s)%n", System.getProperty("os.name"), System.getProperty("os.version"));
        System.out.printf("CPU: %s%n", System.getProperty("os.arch"));
        System.out.printf("Java version: %s%n", System.getProperty("java.version"));
        System.out.printf("Hash bytesize: %d%n", packedSize(data));

        List<Double> createTimes = new ArrayList<>();
        List<Double> readTimes = new ArrayList<>();

        for (int round = 0; round < COUNT_TO_RUN; round++) {
            List<String> tokens = new ArrayList<>(REQUESTS);
            System.out.println("\nChecking scale load...");
            System.out.println("when creates 40k tokens");

            long t1 = System.nanoTime();
            for (int i = 0; i < REQUESTS; i++) {
                String token = Jwts.builder()
                        .setClaims(data)
                        .signWith(SignatureAlgorithm.HS256, HMAC_SECRET.getBytes(StandardCharsets.UTF_8))
                        .compact();
                tokens.add(token);
            }
            long t2 = System.nanoTime();
            double createSec = (t2 - t1) / 1_000_000_000.0;
            createTimes.add(createSec);
            System.out.printf("Create time: %.3f sec%n", createSec);

            long t3 = System.nanoTime();
            for (String tok : tokens) {
                Jwts.parser()
                        .setSigningKey(HMAC_SECRET.getBytes(StandardCharsets.UTF_8))
                        .build()
                        .parseClaimsJws(tok);
            }
            long t4 = System.nanoTime();
            double readSec = (t4 - t3) / 1_000_000_000.0;
            readTimes.add(readSec);
            System.out.printf("Read time: %.3f sec%n", readSec);
        }

        System.out.println("\nOn Create");
        printStats(createTimes);

        System.out.println("\nOn Read");
        printStats(readTimes);
    }

    private static int packedSize(Map<String, Object> data) throws Exception {
        MessageBufferPacker packer = MessagePack.newDefaultBufferPacker();
        packMap(packer, data);
        packer.close();
        return packer.toByteArray().length;
    }

    @SuppressWarnings("unchecked")
    private static void packMap(MessagePacker packer, Map<String, Object> map) throws Exception {
        packer.packMapHeader(map.size());
        for (Map.Entry<String, Object> e : map.entrySet()) {
            packer.packString(e.getKey());
            Object v = e.getValue();
            if (v instanceof String s) packer.packString(s);
            else if (v instanceof Integer i) packer.packInt(i);
            else if (v instanceof Map<?, ?> m) packMap(packer, (Map<String, Object>) m);
            else throw new IllegalArgumentException("Unsupported type: " + v.getClass());
        }
    }

    private static void printStats(List<Double> values) {
        double min = values.stream().mapToDouble(Double::doubleValue).min().orElse(0);
        double max = values.stream().mapToDouble(Double::doubleValue).max().orElse(0);
        double median = median(values);
        System.out.printf("Mediana: %.3f%nMin: %.3f%nMax: %.3f%n", median, min, max);
    }

    private static double median(List<Double> vals) {
        double[] arr = vals.stream().mapToDouble(Double::doubleValue).sorted().toArray();
        int mid = arr.length / 2;
        return arr.length % 2 == 0 ? (arr[mid - 1] + arr[mid]) / 2.0 : arr[mid];
    }
}
