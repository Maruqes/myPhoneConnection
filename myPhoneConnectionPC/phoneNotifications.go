package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

type NotificationAction struct {
	text  string
	index string
	uid   string
}

func getdunstifyPath() string {
	path, err := exec.LookPath("dunstify")
	if err != nil {
		fmt.Println("Error getting dunstify path:", err)
		return ""
	}
	return path
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
			ws.sendData("notAction//" + actions[i].uid + "//" + actions[i].index)
		}
	}

}

func newNotification(fullData string) {
	dataSlice := strings.Split(fullData, "//||//")
	data := dataSlice[0]

	dataIcon, err := base64.StdEncoding.DecodeString(dataSlice[1])
	iconPath := ""
	if err == nil {
		iconPath, err = saveTemporaryImage(dataIcon)
		if err != nil {
			fmt.Println("Error saving temporary image:", err)
		}
	} else {
		fmt.Println("Error decoding image:", err)
	}

	dataMiniIcon, err := base64.StdEncoding.DecodeString(dataSlice[2])
	miniIconPath := ""
	if err == nil {
		miniIconPath, err = saveTemporaryImage(dataMiniIcon)
		if err != nil {
			fmt.Println("Error saving temporary image:", err)
		}
	} else {
		fmt.Println("Error decoding image:", err)
	}

	data = data[1 : len(data)-1]
	data = strings.Replace(data, "\\\"", "\"", -1)

	fmt.Println("New Notification: ", string(data))

	if !json.Valid([]byte(data)) {
		fmt.Println("Invalid JSON:", data)
		return
	}

	var jsonData map[string]interface{}
	err = json.Unmarshal([]byte(data), &jsonData)
	if err != nil {
		fmt.Println("Error converting to JSON:", err)
		return
	}

	title := fmt.Sprintf("%v", jsonData["title"])
	text := fmt.Sprintf("%v", jsonData["text"])

	var actions []NotificationAction

	if jsonData["actions"] != nil {
		for i := range len(jsonData["actions"].([]interface{})) {
			action := jsonData["actions"].([]interface{})[i].(map[string]interface{})
			if action["inputs"] == nil {
				titleNot := fmt.Sprintf("%v", action["title"])
				fmt.Println("Action: ", titleNot)
				actions = append(actions, NotificationAction{titleNot, strconv.Itoa(i), dataSlice[3]})
			}
		}
	}

	go showNotifications(title, text, iconPath, miniIconPath, actions)
}
