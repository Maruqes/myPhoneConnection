package main

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/gen2brain/beeep"
)

func showNotifications(title string) {
	fmt.Println("Title: ", title)
	err := beeep.Notify("Notification", title, "")
	if err != nil {
		fmt.Println("Error showing notification:", err)
	}
}

func newNotification(data string) {
	data = data[1 : len(data)-1]
	data = strings.Replace(data, "\\\"", "\"", -1)

	fmt.Println("New Notification: ", string(data))

	if !json.Valid([]byte(data)) {
		fmt.Println("Invalid JSON:", data)
		return
	}

	var jsonData map[string]interface{}
	err := json.Unmarshal([]byte(data), &jsonData)
	if err != nil {
		fmt.Println("Error converting to JSON:", err)
		return
	}

	title := fmt.Sprintf("%v", jsonData["title"])
	showNotifications(title)
}
