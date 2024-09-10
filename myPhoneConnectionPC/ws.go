package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
)

type Ws struct {
	upgrader websocket.Upgrader
	ws_key   *[]byte
	socket   *websocket.Conn
}

type dataStream struct {
	indentifier string
	function    func(s string)
}

var dataStreams []dataStream

func (ws *Ws) registerDataStreams(indentifiers string, recMsg func(s string)) {
	dataStreams = append(dataStreams, dataStream{indentifiers, recMsg})
}

func (ws *Ws) searchDataStream(indentifiers string) func(s string) {
	for _, d := range dataStreams {
		if d.indentifier == indentifiers {
			return d.function
		}
	}
	return nil
}

func webSocketKilled() {
	log.Println("Websocket killed")
}

func (ws *Ws) recieveData(s []byte, recMsg func(s string)) {
	res, _ := decryptAES(*ws.ws_key, string(s))
	recMsg(res)
}

func (ws *Ws) httpWS(recMsg func(s string), key *[]byte) {
	upgrader := ws.upgrader
	ws.ws_key = key

	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {

		c, err := upgrader.Upgrade(w, r, nil)
		ws.socket = c

		if err != nil {
			log.Print("upgrade:", err)
			return
		}
		defer c.Close()

		pass := r.URL.Query().Get("pass")
		fmt.Println("pass:", pass)
		passdec, err := decryptAES(*ws.ws_key, pass)
		if err != nil {
			log.Println("Error decrypting pass:", err)
			return
		}
		if passdec != "ableToConnect" {
			log.Println("Unauthorized on WS")
			return
		} else {
			log.Println("Connection established")
		}

		for {
			_, message, err := c.ReadMessage()
			if err != nil {
				log.Println("read:", err)
				webSocketKilled()
				break
			}
			ws.recieveData(message, recMsg)
		}
	})
}

func (ws *Ws) isConnectionAlive() bool {
	return ws.socket != nil
}

func (ws *Ws) sendData(indentifier string, s string) {
	if !ws.isConnectionAlive() {
		return
	}
	if s == "" {
		s = "null"
	}
	s = indentifier + "//||DIVIDER||\\\\" + s
	encrypted, _ := encryptAES(*ws.ws_key, s)
	ws.socket.WriteMessage(websocket.TextMessage, []byte(encrypted))
}
