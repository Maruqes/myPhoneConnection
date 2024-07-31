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
	"strings"

	"github.com/shirou/gopsutil/cpu"
	"github.com/shirou/gopsutil/host"
	"github.com/shirou/gopsutil/mem"
)

var ws Ws

type SysInfo struct {
	Hostname string `bson:"hostname"`
	Platform string `bson:"platform"`
	CPU      string `bson:"cpu"`
	RAM      uint64 `bson:"ram"`
}

var PORT = "8080"

func generate_key(modulus string, exponent string) (string, []byte, error) {
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

	key, _ := generateRandomKey(32)

	encryption_key_base64 := []byte(string(base64.StdEncoding.EncodeToString(key)))

	encryptedkey, err := rsa.EncryptPKCS1v15(
		rand.Reader,
		publicKey,
		encryption_key_base64,
	)
	if err != nil {
		fmt.Println("Error encrypting message:", err)
		return "", nil, err
	}

	return base64.StdEncoding.EncodeToString(encryptedkey), key, nil
}

func getPCstats() *SysInfo {
	hostStat, _ := host.Info()
	cpuStat, _ := cpu.Info()
	vmStat, _ := mem.VirtualMemory()

	info := new(SysInfo)

	info.Hostname = hostStat.Hostname
	info.Platform = hostStat.Platform
	info.CPU = cpuStat[0].ModelName
	info.RAM = vmStat.Total / 1024 / 1024
	return info
}

func nextPassSave(s string) {
	nextPassb64 := strings.Replace(s, "nextPass//", "", 1)
	nextPass, err := base64.StdEncoding.DecodeString(nextPassb64)
	if err != nil {
		log.Println("Error decoding nextPass:", err)
	}
	log.Println("Next pass:", nextPass)
	//write this bytes in a file
	err = os.WriteFile("nextPass.bin", nextPass, 0644)
	if err != nil {
		log.Println("Error writing nextPass:", err)
	}
}

func wsMessages(s string) {
	if strings.Contains(s, "nextPass//") {
		nextPassSave(s)
	} else if strings.Contains(s, "imagetest") {
		image_file := strings.Replace(s, "imagetest//", "", 1)

		addCacheImages(image_file, false)

	} else if strings.Contains(s, "imageFirst") {
		image_file := strings.Replace(s, "imageFirst//", "", 1)

		addCacheImages(image_file, false)
		loadCurrentImages()
	} else if s == "createdSocket" {
		addFIRSTImages()
	} else if strings.Contains(s, "updateGallery//") {
		image_file := strings.Replace(s, "updateGallery//", "", 1)

		addCacheImages(image_file, true)
		loadCurrentImages()

	} else {
		log.Println("WS:", s)
	}
}

func serverFunc() {

	info := getPCstats()

	key := []byte{}

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

		//deve aqui aceitar o dispositivo

		// Access the JSON data
		brand := data["brand"].(string)
		model := data["model"].(string)
		id := data["id"].(string)
		publicKey_modulus := data["publicKey_modulus"].(string)
		publicKey_exponent := data["publicKey_exponent"].(string)

		log.Printf("Brand: %s, Model: %s, ID: %s  publicKey: %s ", brand, model, id, publicKey_modulus)

		encryptedkeyBase64, _key, err := generate_key(publicKey_modulus, publicKey_exponent)
		key = _key
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		fmt.Fprintf(w, "%s", encryptedkeyBase64)

	})

	http.HandleFunc("/startNextPassProtocol", func(w http.ResponseWriter, r *http.Request) {
		//get the phone info where it comes from if it matches the one that was connected gives half of the pass
		data, err := ReadFromFile("nextPass.bin")
		if err != nil {
			log.Println("Error reading nextPass:", err)
		}

		last8Bytes := data[len(data)-8:]

		fmt.Fprint(w, base64.StdEncoding.EncodeToString(last8Bytes))
	})

	http.HandleFunc("/nextPassProtocolLastPass", func(w http.ResponseWriter, r *http.Request) {
		var data map[string]interface{}
		err := json.NewDecoder(r.Body).Decode(&data)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}

		// Access the JSON data
		fullPassb64 := data["fullPass"].(string)

		fullPassOUR, err := ReadFromFile("nextPass.bin")
		if err != nil {
			log.Println("Error reading nextPass:", err)
		}

		fullPassOURb64 := base64.StdEncoding.EncodeToString(fullPassOUR)

		if fullPassOURb64 == fullPassb64 {
			fmt.Fprint(w, "OK")
		} else {
			fmt.Fprint(w, "NOTOK")
		}

	})

	ws.httpWS(wsMessages, &key)

	port := os.Getenv("PORT")
	if port == "" {
		port = PORT
	}

	log.Printf("Server listening on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func main() {
	go serverFunc()
	createUI()
}
