package main

import (
	"fmt"
	"log"
	"strings"
	"time"

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
var lastPlayer string

func pauseOrPlayMedia() {
	conn, err := dbus.SessionBus()
	if err != nil {
		log.Fatalf("Failed to connect to session bus: %v", err)
	}

	object := conn.Object(lastPlayer, "/org/mpris/MediaPlayer2")
	call := object.Call("org.mpris.MediaPlayer2.Player.PlayPause", 0)
	if call.Err != nil {
		log.Fatalf("Failed to pause or play media: %v", call.Err)
	}
}

func mediaAction(media string) {

	if media == "pause" {
		pauseOrPlayMedia()
	} else if media == "next" {
	} else if media == "previous" {
	}
}

func placeAtLast(sender string) {
	for i, v := range currentPlayer {
		if v.currentPlayer == sender {
			currentPlayer = append(currentPlayer[:i], currentPlayer[i+1:]...)
			currentPlayer = append(currentPlayer, v)
			break
		}
	}
}

func printAllProperties() {
	log.Println("Current players len: " + fmt.Sprintf("%d", len(currentPlayer)))
	for _, v := range currentPlayer {
		fmt.Printf("Owner: %s\n", v.currentPlayer)
		for _, p := range v.properties {
			fmt.Printf("Property: %s = %s\n", p.key, p.value)
		}
	}
}

func getPosition(owner string) (int, error) {
	conn, err := dbus.SessionBus()
	if err != nil {
		return 0, err
	}

	object := conn.Object(owner, "/org/mpris/MediaPlayer2")
	call := object.Call("org.freedesktop.DBus.Properties.Get", 0, "org.mpris.MediaPlayer2.Player", "Position")
	if call.Err != nil {
		return 0, call.Err
	}

	var position int64
	err = call.Store(&position)
	if err != nil {
		return 0, err
	}

	return int(position), nil
}

func routineToSyncPosition() {
	for {
		time.Sleep(1 * time.Second)
		if len(currentPlayer) == 0 {
			continue
		}

		position, err := getPosition(currentPlayer[len(currentPlayer)-1].currentPlayer)
		if err != nil {
			// log.Printf("Error getting position: %v", err)
		} else {
			stringPosition := fmt.Sprintf("%d", position)
			ws.sendData(fmt.Sprintf("setMediaPosition//" + stringPosition))
		}
	}
}

func syncDataWithWS() {
	ws.sendData("clearMediaPlayer")

	curPlayer := currentPlayer[len(currentPlayer)-1]
	log.Printf("Syncing data for player: %s\n", curPlayer.currentPlayer)
	for i, p := range curPlayer.properties {
		if i == len(curPlayer.properties)-1 {
			ws.sendData(fmt.Sprintf("dataMediaPlayer//||//%s:div:%s:div:%s:div:END", curPlayer.currentPlayer, p.key, p.value))
		}
		ws.sendData(fmt.Sprintf("dataMediaPlayer//||//%s:div:%s:div:%s:div:NOTEND", curPlayer.currentPlayer, p.key, p.value))
	}
	lastPlayer = curPlayer.currentPlayer
}

func changePropertiesOrAddNew(sender string, propertie Properties) {
	defer func() {
		if sender != lastPlayer {
			placeAtLast(sender)
		}
	}()
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

func getAllProperties(owner string) {
	conn, err := dbus.SessionBus()
	if err != nil {
		log.Fatalf("Failed to connect to session bus: %v", err)
	}

	object := conn.Object(owner, "/org/mpris/MediaPlayer2")
	call := object.Call("org.freedesktop.DBus.Properties.GetAll", 0, "org.mpris.MediaPlayer2.Player")
	if call.Err != nil {
		log.Fatalf("Failed to get all properties: %v", call.Err)
	}

	properties := call.Body[0].(map[string]dbus.Variant)
	for key, value := range properties {
		newProperty := Properties{key: key, value: value.String()}
		changePropertiesOrAddNew(owner, newProperty)
	}
}

func getAllCurrentOwners() {
	// Connect to the session bus (user-level D-Bus)
	conn, err := dbus.SessionBus()
	if err != nil {
		log.Fatalf("Failed to connect to session bus: %v", err)
	}

	// List all names on the bus
	var busNames []string
	err = conn.BusObject().Call("org.freedesktop.DBus.ListNames", 0).Store(&busNames)
	if err != nil {
		log.Fatalf("Failed to list names on the bus: %v", err)
	}

	for _, service := range busNames {
		if strings.Contains(service, "org.mpris.MediaPlayer2") {
			// Get the owner of the service
			var owner string
			err = conn.BusObject().Call("org.freedesktop.DBus.GetNameOwner", 0, service).Store(&owner)
			if err != nil {
				log.Printf("Failed to get owner of %s: %v", service, err)
				continue
			}
			fmt.Printf("Service: %s, Owner: %s\n", service, owner)
			newMediaPlayer := MediaPlayer{currentPlayer: owner}
			currentPlayer = append(currentPlayer, newMediaPlayer)
			getAllProperties(owner)
		}
	}
}

func listenToChangesAndOwner() {
	getAllCurrentOwners()
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

	go routineToSyncPosition()

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