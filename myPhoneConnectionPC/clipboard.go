package main

import (
	"context"
	"encoding/base64"

	"golang.design/x/clipboard"
)

func handleClipImg(img []byte) {
	imgb64 := base64.StdEncoding.EncodeToString(img)
	ws.sendData("clipboardIMG", imgb64)
}

func handleClipText(text string) {
	ws.sendData("clipboard", text)
}

func clipboardCopyCallBack() {
	go func() {
		clipTXT := clipboard.Watch(context.TODO(), clipboard.FmtText)
		for data := range clipTXT {
			handleClipText(string(data))
		}
	}()

	go func() {
		clipIMG := clipboard.Watch(context.TODO(), clipboard.FmtImage)
		for data := range clipIMG {
			handleClipImg(data)
		}
	}()
}
