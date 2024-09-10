package main

import (
	"encoding/base64"
	"fmt"
	"os/exec"
	"regexp"
	"strings"
)

func amixerPath() string {
	path, err := exec.LookPath("amixer")
	if err != nil {
		fmt.Println("Error getting amixer path:", err)
		return ""
	}
	return path
}

func getCurrentVolume() (string, error) {
	amixer := amixerPath()
	if amixer == "" {
		fmt.Println("amixer not found")
		return "", fmt.Errorf("amixer not found")
	}

	cmd := exec.Command(amixer, "get", "Master")
	output, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Println("Error getting volume:", err)
		return "", err
	}

	outputStr := string(output)

	re := regexp.MustCompile(`\[(\d+)%\]`)
	matches := re.FindStringSubmatch(outputStr)

	if len(matches) <= 1 {
		return "", fmt.Errorf("could not find volume information")
	}

	volume := matches[1]
	volume = strings.Trim(volume, " ")
	return volume, nil
}

func setSystemVolume(volume string) {
	amixer := amixerPath()
	if amixer == "" {
		fmt.Println("amixer not found")
		return
	}

	fmt.Println("Setting volume to", volume)
	cmd := exec.Command(amixer, "set", "Master", volume+"%")
	fmt.Println("Command:", cmd)
	err := cmd.Run()
	if err != nil {
		fmt.Println("Error lowering volume:", err)
	}
}

func getIcon(iconb64 string) string {
	if iconb64 == "empty" {
		return ""
	}
	iconPath := ""
	icon, err := base64.StdEncoding.DecodeString(iconb64)
	if err != nil {
		fmt.Println("Error decoding icon:", err)
		iconPath = ""
	} else {
		iconPath, err = saveTemporaryImage(icon)
		if err != nil {
			fmt.Println("Error saving temporary image:", err)
			iconPath = ""
		}
	}

	return iconPath
}

var lastVolume string
var lastVolumeSet bool
var pausedMediaByCall bool

func getCall(s string) {
	res := strings.Split(s, "//||//")
	number := res[0]
	status := res[1]
	displayName := res[2]
	iconb64 := res[3]

	iconPath := getIcon(iconb64)

	nameOrNumber := displayName
	if displayName == "empty" {
		nameOrNumber = number
	}
	if res[1] == "PhoneStateStatus.CALL_INCOMING" {
		volume, err := getCurrentVolume()
		if err == nil {
			lastVolume = volume
			lastVolumeSet = true
			fmt.Println("Volume:", volume)
			setSystemVolume("25")
		}

		showNotifications("Call", "You have a call from "+nameOrNumber, iconPath, "", []NotificationAction{})
	} else if res[1] == "PhoneStateStatus.CALL_ENDED" {

		if pausedMediaByCall {
			playMedia()
		}

		if lastVolumeSet {
			setSystemVolume(lastVolume)
			lastVolumeSet = false
		}

		showNotifications("Call", "The call from "+nameOrNumber+"  has ended", iconPath, "", []NotificationAction{})
	} else if res[1] == "PhoneStateStatus.CALL_STARTED" {

		pausedMediaByCall = pauseMedia()

		showNotifications("Call", "The call from "+nameOrNumber+"  has started", iconPath, "", []NotificationAction{})
	} else {
		fmt.Println("Unknown status from " + nameOrNumber + ": " + status)
	}
}
