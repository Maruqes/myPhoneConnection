package main

import (
	"log"
	"net/http"

	"github.com/gorilla/websocket"
)

type Ws struct {
	upgrader websocket.Upgrader
	ws_key   *[]byte
	socket   *websocket.Conn
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

		for {
			_, message, err := c.ReadMessage()
			if err != nil {
				log.Println("read:", err)
				break
			}
			ws.recieveData(message, recMsg)
		}
	})
}

func (ws *Ws) isConnectionAlive() bool {
	return ws.socket != nil
}

func (ws *Ws) sendData(s string) {
	if !ws.isConnectionAlive() {
		return
	}
	encrypted, _ := encryptAES(*ws.ws_key, s)
	ws.socket.WriteMessage(websocket.TextMessage, []byte(encrypted))
}
