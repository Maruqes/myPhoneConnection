package main

import (
	"crypto/rand"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"os"

	"github.com/shirou/gopsutil/cpu"
	"github.com/shirou/gopsutil/host"
	"github.com/shirou/gopsutil/mem"
)

type SysInfo struct {
	Hostname string `bson:hostname`
	Platform string `bson:platform`
	CPU      string `bson:cpu`
	RAM      uint64 `bson:ram`
}

var PORT = "8080"

func generate_key(modulus string, exponent string) (string, error) {
	//convert string to int
	publicKey_modulus_int := new(big.Int)
	publicKey_modulus_int.SetString(modulus, 10)

	publicKey_exponent_int := new(big.Int)
	publicKey_exponent_int.SetString(exponent, 10)

	//generate public keu with modulus and exponent
	publicKey := &rsa.PublicKey{
		N: publicKey_modulus_int,
		E: int(publicKey_exponent_int.Int64()),
	}

	key, _ := generateRandomKey(64)

	encryption_key_base64 := []byte(string(base64.StdEncoding.EncodeToString(key)))

	encryptedkey, err := rsa.EncryptPKCS1v15(
		rand.Reader,
		publicKey,
		encryption_key_base64,
	)
	if err != nil {
		fmt.Println("Error encrypting message:", err)
		return "", err
	}

	return base64.StdEncoding.EncodeToString(encryptedkey), nil
}

func main() {
	hostStat, _ := host.Info()
	cpuStat, _ := cpu.Info()
	vmStat, _ := mem.VirtualMemory()

	info := new(SysInfo)

	info.Hostname = hostStat.Hostname
	info.Platform = hostStat.Platform
	info.CPU = cpuStat[0].ModelName
	info.RAM = vmStat.Total / 1024 / 1024

	http.HandleFunc("/do_i_exist", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "My Phone Connection%s//%s//%s//%d", info.Hostname, info.Platform, info.CPU, info.RAM)

		brand := r.URL.Query().Get("brand")
		model := r.URL.Query().Get("model")
		serialNumber := r.URL.Query().Get("serialNumber")

		log.Printf("Brand: %s, Model: %s, ID: %s", brand, model, serialNumber)

	})

	//handle post /connect
	http.HandleFunc("/connect", func(w http.ResponseWriter, r *http.Request) {

		// Read JSON from request body
		var data map[string]interface{}
		err := json.NewDecoder(r.Body).Decode(&data)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		// Access the JSON data
		brand := data["brand"].(string)
		model := data["model"].(string)
		id := data["id"].(string)
		publicKey_modulus := data["publicKey_modulus"].(string)
		publicKey_exponent := data["publicKey_exponent"].(string)

		log.Printf("Brand: %s, Model: %s, ID: %s  publicKey: %s ", brand, model, id, publicKey_modulus)

		encryptedkeyBase64, err := generate_key(publicKey_modulus, publicKey_exponent)
		
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		fmt.Fprintf(w, "%s", encryptedkeyBase64)

		fmt.Println("encryptedkeyBase64: ", encryptedkeyBase64)
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = PORT
	}

	log.Printf("Server listening on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
