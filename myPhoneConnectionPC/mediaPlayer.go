package main

import (
	"fmt"
	"log"
	"strings"

	"github.com/godbus/dbus/v5"
)

type Properties struct {
	key   string
	value string
}

type MediaPlayer struct {
	currentPlayer string
	properties    []Properties
}

var currentPlayer []MediaPlayer

func syncDataWithWS() {
	ws.sendData("clearMediaPlayer")
	for _, v := range currentPlayer {
		for i, p := range v.properties {
			if i == len(v.properties)-1 {
				ws.sendData(fmt.Sprintf("dataMediaPlayer//||//%s:div:%s:div:%s:div:END", v.currentPlayer, p.key, p.value))
			}
			ws.sendData(fmt.Sprintf("dataMediaPlayer//||//%s:div:%s:div:%s:div:NOTEND", v.currentPlayer, p.key, p.value))
		}
	}
}

func changePropertiesOrAddNew(sender string, propertie Properties) {
	//if propertie exists change else add new
	for i, v := range currentPlayer {
		if v.currentPlayer == sender {
			for j, p := range v.properties {
				if p.key == propertie.key {
					currentPlayer[i].properties[j] = propertie
					return
				}
			}
			currentPlayer[i].properties = append(currentPlayer[i].properties, propertie)
			return
		}
	}
}

func listenToChangesAndOwner() {
	// Connect to the session bus
	conn, err := dbus.SessionBus()
	if err != nil {
		log.Fatalf("Failed to connect to session bus: %v", err)
	}

	// Subscribe to the PropertiesChanged signal on any MPRIS player
	ruleProps := "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='/org/mpris/MediaPlayer2'"
	call := conn.BusObject().Call("org.freedesktop.DBus.AddMatch", 0, ruleProps)
	if call.Err != nil {
		log.Fatalf("Failed to add match: %v", call.Err)
	}

	// Subscribe to the NameOwnerChanged signal
	ruleOwner := "type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged'"
	call = conn.BusObject().Call("org.freedesktop.DBus.AddMatch", 0, ruleOwner)
	if call.Err != nil {
		log.Fatalf("Failed to add match: %v", call.Err)
	}

	// Channel to receive D-Bus messages
	c := make(chan *dbus.Signal, 10)
	conn.Signal(c)

	// Listening loop
	for signal := range c {
		// Check for PropertiesChanged signals
		if signal.Name == "org.freedesktop.DBus.Properties.PropertiesChanged" {
			if len(signal.Body) > 1 {
				interfaceName := signal.Body[0].(string)
				if interfaceName == "org.mpris.MediaPlayer2.Player" {
					changedProps := signal.Body[1].(map[string]dbus.Variant)
					for key, value := range changedProps {
						fmt.Printf("Property changed: %s = %v\n", key, value)
						newProperty := Properties{key: key, value: value.String()}
						changePropertiesOrAddNew(signal.Sender, newProperty)
						syncDataWithWS()
					}
				}
			}
		}

		// Check for NameOwnerChanged signals
		if signal.Name == "org.freedesktop.DBus.NameOwnerChanged" {
			if len(signal.Body) == 3 {
				name := signal.Body[0].(string)
				if strings.Contains(name, "org.mpris.MediaPlayer2") {
					oldOwner := signal.Body[1].(string)
					newOwner := signal.Body[2].(string)

					if newOwner == "" {
						fmt.Printf("Service '%s' has been terminated (old owner: %s)\n", name, oldOwner)
						for i, v := range currentPlayer {
							if v.currentPlayer == oldOwner {
								currentPlayer = append(currentPlayer[:i], currentPlayer[i+1:]...)
								break
							}
						}

					} else {
						fmt.Printf("Service '%s' started (new owner: %s)\n", name, newOwner)
						newMediaPlayer := MediaPlayer{currentPlayer: newOwner}
						currentPlayer = append(currentPlayer, newMediaPlayer)
					}
				}
			}
		}
	}
}
