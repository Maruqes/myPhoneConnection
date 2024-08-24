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

/*
	IMPORTANTE: DELETION OF IMAGES ON PHONE
	AINDA TENS DE VER A CONEXÃO COM O PHONE
*/

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
	fullData := strings.Split(s, "//||DIVIDER||\\\\") /// [0] is the identifier, [1] is the data
	funcToCall := ws.searchDataStream(fullData[0])

	if funcToCall != nil {
		funcToCall(fullData[1])
	}
}

func checkFullPass(fullPassb64 string) bool {
	fullPassOUR, err := ReadFromFile("nextPass.bin")
	if err != nil {
		log.Println("Error reading nextPass:", err)
	}

	fullPassOURb64 := base64.StdEncoding.EncodeToString(fullPassOUR)

	if fullPassOURb64 == fullPassb64 {
		return true
	} else {
		return false
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

		// Access the JSON data
		brand := data["brand"].(string)
		model := data["model"].(string)
		id := data["id"].(string)
		publicKey_modulus := data["publicKey_modulus"].(string)
		publicKey_exponent := data["publicKey_exponent"].(string)
		fullPassb64 := data["fullPass"].(string)

		log.Println("FullPass:", fullPassb64)

		if fullPassb64 == "" {
			//should ask for connection with a pop up to let it go through
			accepted, err := showAcceptPhoneNotification(brand, model)
			if err != nil {
				fmt.Fprintf(w, "Error showing notification")
				fmt.Println("Error showing notification")
				return
			}
			if !accepted {
				fmt.Fprintf(w, "Connection not accepted")
				fmt.Println("Connection not accepted")
				return
			}
		} else {
			if !checkFullPass(fullPassb64) {
				fmt.Fprintf(w, "fullPass not correct")
				fmt.Println("fullPass not correct")
				return
			}
		}

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

	ws.httpWS(wsMessages, &key)

	port := os.Getenv("PORT")
	if port == "" {
		port = PORT
	}

	log.Printf("Server listening on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func printit(s string) {
	log.Println(s)
}

func main() {
	ws.registerDataStreams("null", printit)
	ws.registerDataStreams("nextPass", nextPassSave)
	ws.registerDataStreams("imagetest", addCacheImagesFalse)
	ws.registerDataStreams("imageFirst", addCacheImagesFalse)
	ws.registerDataStreams("createdSocket", addFIRSTImages)
	ws.registerDataStreams("updateGallery", addCacheImagesFirst)
	ws.registerDataStreams("fullImage", showImageInModal)
	ws.registerDataStreams("fullVIDEO", showVideoInModal)
	ws.registerDataStreams("media", mediaAction)
	ws.registerDataStreams("newPhoneNotification", newNotification)

	go serverFunc()
	go listenToChangesAndOwner()
	go clipboardCopyCallBack()
	createUI()
}
