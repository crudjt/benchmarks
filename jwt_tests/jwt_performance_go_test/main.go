package main

import (
    "fmt"
    "os/exec"
    "runtime"
    "sort"
    "strings"
    "time"
    "github.com/golang-jwt/jwt/v5"
)

const (
    MaxHashSize = 256
    Requests = 40000
    Rounds = 10
    Alg = "HS256"
)

var HMACSecret = []byte("Cm7B68NWsMNNYjzMDREacmpe5sI1o0g40ZC9w1yQW3WOes7Gm59UsittLOHR2dciYiwmaYq98l3tG8h9yXVCxg==")

func main() {
    // OS / Go version
    osVersion := detectOSVersion()
    fmt.Printf("OS: %s (%s) version %s\n", runtime.GOOS, runtime.GOARCH, osVersion)
    fmt.Printf("Go version: %s\n", runtime.Version())

    isoNow := time.Now().UTC().Format(time.RFC3339)
    data := map[string]any{
        "user_id": 414243,
        "role": 11,
        "devices": map[string]any{
            "ios_expired_at": isoNow,
            "android_expired_at": isoNow,
        },
        "a": strings.Repeat("a", 100),
    }
    data = adjustData(data, MaxHashSize)
    fmt.Printf("Hash bytesize: %d\n", payloadSize(data))

    createTimes := make([]float64, 0, Rounds)
    verifyTimes := make([]float64, 0, Rounds)

    for r := 1; r <= Rounds; r++ {
        fmt.Printf("\n=== Round %d ===\n", r)
        // --- create
        start := time.Now()
        tokens := make([]string, Requests)
        for i := 0; i < Requests; i++ {
            tok, err := createJWT(data)
            if err != nil {
                panic(err)
            }
            tokens[i] = tok
        }
        createSec := time.Since(start).Seconds()
        fmt.Printf("Create time for %d tokens: %.3f sec\n", Requests, createSec)

        // --- read
        start = time.Now()
        for _, t := range tokens {
            _, err := verifyJWT(t)
            if err != nil {
                panic(err)
            }
        }
        verifySec := time.Since(start).Seconds()
        fmt.Printf("Read time for %d tokens: %.3f sec\n", Requests, verifySec)

        createTimes = append(createTimes, createSec)
        verifyTimes = append(verifyTimes, verifySec)
    }

    printStats("On Create", createTimes)
    printStats("On Read", verifyTimes)
}

func createJWT(data map[string]any) (string, error) {
    claims := jwt.MapClaims(data)
    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString(HMACSecret)
}

func verifyJWT(tokenString string) (jwt.MapClaims, error) {
    token, err := jwt.Parse(tokenString, func(t *jwt.Token) (interface{}, error) {
        return HMACSecret, nil
    })
    if err != nil {
        return nil, err
    }

    if claims, ok := token.Claims.(jwt.MapClaims); ok && token.Valid {
        return claims, nil
    }
    return nil, fmt.Errorf("invalid token")
}

// -------- helpers --------
func adjustData(data map[string]any, max int) map[string]any {
    for payloadSize(data) > max {
        a := data["a"].(string)
        if len(a) == 0 {
            break
        }
        data["a"] = a[:len(a)-1]
    }
    return data
}

func payloadSize(m map[string]any) int {
    tok := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims(m))
    str, _ := tok.SigningString()
    return len(str)
}

func printStats(label string, times []float64) {
    sort.Float64s(times)
    n := len(times)
    median := times[n/2]
    if n%2 == 0 {
        median = (times[n/2-1] + times[n/2]) / 2
    }
    fmt.Printf("\n%s\nMedian: %.3f\nMin: %.3f\nMax: %.3f\n",
        label, median, times[0], times[n-1])
}

func detectOSVersion() string {
    if runtime.GOOS == "darwin" {
        out, _ := exec.Command("sw_vers", "-productVersion").Output()
        return strings.TrimSpace(string(out))
    }
    if runtime.GOOS == "linux" {
        out, _ := exec.Command("uname", "-r").Output()
        return strings.TrimSpace(string(out))
    }
    return "unknown"
}
