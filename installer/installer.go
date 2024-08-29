package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"

	"github.com/emersion/go-autostart"
)

func downloadExecutable() {
	resp, err := http.Get("https://github.com/Maruqes/myPhoneConnection/releases/download/v0.2/myPhoneConnection")
	if err != nil {
		log.Fatal(err)
	}
	defer resp.Body.Close()

	usr, err := user.Current()
	if err != nil {
		log.Fatal(err)
	}

	folderPath := filepath.Join(usr.HomeDir, "myPhoneConnection")
	if err := os.MkdirAll(folderPath, os.ModePerm); err != nil {
		log.Fatal(err)
	}

	filePath := filepath.Join(folderPath, "myPhoneConnection")
	file, err := os.Create(filePath)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	_, err = io.Copy(file, resp.Body)
	if err != nil {
		log.Fatal(err)
	}

	if err := os.Chmod(filePath, 0755); err != nil {
		log.Fatal(err)
	}
}

func main() {

	//detect is run as sudo
	if os.Geteuid() == 0 {
		log.Fatal("Please run this script as a normal user, not as root or using sudo.")
	}

	downloadExecutable()

	usr, err := user.Current()
	if err != nil {
		log.Fatal(err)
	}

	app := &autostart.App{
		Name:        "My Phone Connection",
		DisplayName: "PH",
		Exec:        []string{filepath.Join(usr.HomeDir, "myPhoneConnection", "myPhoneConnection")},
	}
	en, path := app.IsEnabled()
	fmt.Println(path)
	if en {
		log.Println("App is already enabled")
	} else {
		log.Println("Enabling app...")

		if err := app.Enable(); err != nil {
			log.Fatal(err)
		}
	}

	log.Println("Done!")

	cmd := exec.Command(filepath.Join(usr.HomeDir, "myPhoneConnection", "myPhoneConnection"))
	if err := cmd.Start(); err != nil {
		log.Fatal(err)
	}
}
