package main

import (
	"bytes"
	"fmt"
	"os/exec"
	"runtime"
	"sort"
	"strings"
	"time"

	"github.com/vmihailenco/msgpack/v5"
	"github.com/crudjt/crudjt-go"
)

const (
	COUNT_TO_RUN = 10
	REQUESTS = 40_000
	MAX_HASH_SIZE = 256
)

func osVersion() string {
	switch runtime.GOOS {
	case "darwin":
		out, _ := exec.Command("sw_vers", "-productVersion").Output()
		return strings.TrimSpace(string(out))
	case "linux":
		out, _ := exec.Command("uname", "-r").Output()
		return strings.TrimSpace(string(out))
	case "windows":
		out, _ := exec.Command("cmd", "/c", "ver").Output()
		return strings.TrimSpace(string(out))
	default:
		return "unknown"
	}
}

func msgpackSize(v interface{}) int {
	var buf bytes.Buffer
	enc := msgpack.NewEncoder(&buf)
	_ = enc.Encode(v)
	return buf.Len()
}

func median(vals []float64) float64 {
	sort.Float64s(vals)
	mid := len(vals) / 2
	if len(vals)%2 == 1 {
		return vals[mid]
	}
	return (vals[mid-1] + vals[mid]) / 2
}

func main() {
	crudjt.StartMaster(crudjt.ServerConfig	{
	  SecretKey: "Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg==",
	})

	fmt.Printf("OS: %s (%s)\n", runtime.GOOS, osVersion())
	fmt.Printf("CPU: %s\n", runtime.GOARCH)
	fmt.Printf("Go version: %s\n", runtime.Version())

	data := map[string]interface{}{
		"user_id": 414243,
		"role": 11,
		"devices": map[string]string{
			"ios_expired_at": time.Now().String(),
			"android_expired_at": time.Now().String(),
		},
		"a": strings.Repeat("a", 100),
	}

	for msgpackSize(data) > MAX_HASH_SIZE {
		a := data["a"].(string)
		if len(a) == 0 {
			break
		}
		data["a"] = a[:len(a)-1]
	}

	updated := map[string]interface{}{"user_id": 42, "role": 11}
	fmt.Printf("Hash bytesize: %d\n", msgpackSize(data))

	createTimes := []float64{}
	readTimes := []float64{}
	updateTimes := []float64{}
	deleteTimes := []float64{}

	for run := 0; run < COUNT_TO_RUN; run++ {
		// create
		fmt.Println("when creates 40k tokens")
		tokens := make([]string, 0, REQUESTS)
		start := time.Now()
		for i := 0; i < REQUESTS; i++ {
			v, _ := crudjt.Create(&data, nil, nil)
			tokens = append(tokens, v)
		}
		elapsed := time.Since(start).Seconds()
		createTimes = append(createTimes, elapsed)
		fmt.Printf("%.3f seconds\n", elapsed)

		// read
		fmt.Println("when reads 40k tokens")
		start = time.Now()
		for i := 0; i < REQUESTS; i++ {
			_, _ = crudjt.Read(tokens[i])
		}
		elapsed = time.Since(start).Seconds()
		readTimes = append(readTimes, elapsed)
		fmt.Printf("%.3f seconds\n", elapsed)

		// update
		fmt.Println("when updates 40k tokens")
		start = time.Now()
		for i := 0; i < REQUESTS; i++ {
			_, _ = crudjt.Update(tokens[i], &updated, nil, nil)
		}
		elapsed = time.Since(start).Seconds()
		updateTimes = append(updateTimes, elapsed)
		fmt.Printf("%.3f seconds\n", elapsed)

		// delete
		fmt.Println("when deletes 40k tokens")
		start = time.Now()
		for i := 0; i < REQUESTS; i++ {
			_, _ = crudjt.Delete(tokens[i])
		}
		elapsed = time.Since(start).Seconds()
		deleteTimes = append(deleteTimes, elapsed)
		fmt.Printf("%.3f seconds\n", elapsed)
		fmt.Println()
	}

	// results
	fmt.Println("On Create")
	fmt.Printf("Median: %.3f\nMin: %.3f\nMax: %.3f\n\n",
		median(createTimes), min(createTimes), max(createTimes))

	fmt.Println("On Read")
	fmt.Printf("Median: %.3f\nMin: %.3f\nMax: %.3f\n\n",
		median(readTimes), min(readTimes), max(readTimes))

	fmt.Println("On Update")
	fmt.Printf("Median: %.3f\nMin: %.3f\nMax: %.3f\n\n",
		median(updateTimes), min(updateTimes), max(updateTimes))

	fmt.Println("On Delete")
	fmt.Printf("Median: %.3f\nMin: %.3f\nMax: %.3f\n",
		median(deleteTimes), min(deleteTimes), max(deleteTimes))
}

func min(v []float64) float64 { sort.Float64s(v); return v[0] }
func max(v []float64) float64 { sort.Float64s(v); return v[len(v)-1] }
