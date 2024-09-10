package main

import (
	"encoding/base64"
	"errors"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"
)

type NotificationAction struct {
	text     string
	index    string
	function func()
	id       string
	input    bool
}

func getdunstifyPath() string {
	path, err := exec.LookPath("dunstify")
	if err != nil {
		fmt.Println("Error getting dunstify path:", err)
		return ""
	}
	return path
}

func showAcceptPhoneNotification(title string, text string) (bool, error) {
	dunstifyPath := getdunstifyPath()
	if dunstifyPath == "" {
		fmt.Println("dunstify not found")
		return false, errors.New("dunstify not found")
	}

	accept := "Accept"
	decline := "Decline"

	command := dunstifyPath + " " + "\"" + title + "\"" + " " + "\"" + text + "\"" + " --action=" + "\"" + accept + "\"" + "," + "\"Accept\" --action=" + "\"" + decline + "\"" + "," + "\"Decline\""
	log.Println("Command: ", command)
	cmd := exec.Command("sh", "-c", command)
	output, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Println("Error executing command:", err)
	}

	out := strings.ReplaceAll(string(output), "\n", "")
	if out == accept {
		fmt.Println("Action: ", "Accept")
		return true, nil
	} else if out == decline {
		fmt.Println("Action: ", "Decline")
		return false, nil
	} else {
		return false, errors.New("no action")
	}
}

func showNotifications(title string, text string, iconPath string, miniIconPath string, actions []NotificationAction) {

	defer func() {
		if iconPath != "" {
			err := os.Remove(iconPath)
			if err != nil {
				fmt.Println("Error deleting temporary image:", err)
			}
		}

		if miniIconPath != "" {
			err := os.Remove(miniIconPath)
			if err != nil {
				fmt.Println("Error deleting temporary image:", err)
			}
		}

	}()

	//q crl fazr o -r 1
	dunstifyPath := getdunstifyPath()
	if dunstifyPath == "" {
		fmt.Println("dunstify not found")
		return
	}
	command := dunstifyPath + " " + "\"" + title + "\"" + " " + "\"" + text + "\""

	if iconPath != "" {
		command = command + " -I " + iconPath
	}
	if miniIconPath != "" {
		command = command + " -i " + miniIconPath
	}

	for i := range actions {
		command = command + " --action=" + "\"" + actions[i].index + "\"" + "," + "\"" + actions[i].text + "\""
	}

	log.Println("Command: ", command)
	cmd := exec.Command("sh", "-c", command)
	output, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Println("Error executing command:", err)
	}

	out := strings.ReplaceAll(string(output), "\n", "")
	for i := range actions {
		if out == actions[i].index {
			fmt.Println("Action: ", actions[i].text)
			actions[i].function()
		}
	}
}

func openInstagram() {
	cmd := exec.Command("xdg-open", "https://www.instagram.com/direct/")
	err := cmd.Run()
	if err != nil {
		fmt.Println("Error opening Instagram:", err)
	}
}

func openWhatsApp() {
	cmd := exec.Command("xdg-open", "https://web.whatsapp.com/")
	err := cmd.Run()
	if err != nil {
		fmt.Println("Error opening WhatsApp:", err)
	}
}

func newNotification(fullData string) {
	dataSlice := strings.Split(fullData, "//||//")

	if dataSlice[2] != "null" {
		dataSlice[2] = strings.Replace(dataSlice[2], "data:image/png;base64,", "", -1)
	}
	dataIcon, err := base64.StdEncoding.DecodeString(dataSlice[2])
	iconPath := ""
	if err == nil {
		iconPath, err = saveTemporaryImage(dataIcon)
		if err != nil {
			fmt.Println("Error saving temporary image:", err)
		}
	} else {
		fmt.Println("Error decoding image:", err)
	}

	if dataSlice[3] != "null" {
		dataSlice[3] = strings.Replace(dataSlice[3], "data:image/png;base64,", "", -1)
	}
	dataMiniIcon, err := base64.StdEncoding.DecodeString(dataSlice[3])
	miniIconPath := ""
	if err == nil {
		miniIconPath, err = saveTemporaryImage(dataMiniIcon)
		if err != nil {
			fmt.Println("Error saving temporary image:", err)
		}
	} else {
		fmt.Println("Error decoding image:", err)
	}

	actions := []NotificationAction{}
	if dataSlice[4] == "com.instagram.android" {
		actions = append(actions, NotificationAction{text: "Open Instagram", index: "openInstagram", function: openInstagram, input: false})
	} else if dataSlice[4] == "com.whatsapp" {
		actions = append(actions, NotificationAction{text: "Open WhatsApp", index: "openWhatsApp", function: openWhatsApp, input: false})
	}

	if dataSlice[5] == "true" {
		actions = append(actions, NotificationAction{text: "Reply", index: "replyText", function: func() {
			commandToGetReply := "zenity --entry --text \"Enter your message:\" --title \"Input Required\" 2>/dev/null"

			cmd := exec.Command("sh", "-c", commandToGetReply)
			output, err := cmd.CombinedOutput()
			if err != nil {
				fmt.Println("Error executing command:", err)
			}

			out := strings.ReplaceAll(string(output), "\n", "")
			fmt.Println("Reply: ", out)
			ws.sendData("replyNotification", dataSlice[6]+"//||//"+out)

		}, input: true, id: dataSlice[6]})
	}

	go showNotifications(dataSlice[0], dataSlice[1], iconPath, miniIconPath, actions)
}
