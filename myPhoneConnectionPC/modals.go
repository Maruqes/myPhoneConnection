package main

import (
	"encoding/base64"
	"fmt"
	"image/color"
	"log"
	"os"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/storage"
	"fyne.io/fyne/v2/widget"
	"github.com/metal3d/fyne-streamer/video"
)

var (
	currentIndexOnModal int
)

func showVideoInModal2(file string) {
	u := storage.NewFileURI(file)
	viewer := video.NewPlayer()
	viewer.Open(u)

	viewer.SetMinSize(fyne.NewSize(800, 600))

	var modal *widget.PopUp

	quitButton := widget.NewButton("Quit", func() {
		modal.Hide()
		mainWindow.Canvas().Overlays().Remove(modal)
		viewer.Stop()
	})
	content := container.NewVBox(viewer, quitButton)

	modal = widget.NewModalPopUp(content, mainWindow.Canvas())

	modal.Show()

	viewer.Play()

	// Detect ESC key press
	mainWindow.Canvas().SetOnTypedKey(func(keyEvent *fyne.KeyEvent) {
		if keyEvent.Name == fyne.KeyEscape {
			modal.Hide()
			mainWindow.Canvas().Overlays().Remove(modal)
			viewer.Stop()

			mainWindow.Canvas().SetOnTypedKey(func(keyEvent *fyne.KeyEvent) {
			})
		}
	})

}

func showVideoInModal(vid64 string) {
	vid, err := base64.StdEncoding.DecodeString(vid64)
	if err != nil {
		log.Printf("Error decoding base64 image: %v", err)
		return
	}

	vidDecompressed, err := decompressData(vid)
	if err != nil {
		log.Printf("Error decompressing image data: %v", err)
		return
	}

	//save video .mp4
	file, err := os.CreateTemp("", "video*.mp4")
	if err != nil {
		log.Printf("Error creating video file: %v", err)
		return
	}
	defer file.Close()

	_, err = file.Write(vidDecompressed)
	if err != nil {
		log.Printf("Error writing video data to file: %v", err)
		return
	}

	log.Println("Video saved successfully")
	showVideoInModal2(file.Name())
}

func removeFromCanvas(objects ...fyne.CanvasObject) {
	for _, object := range objects {
		mainWindow.Canvas().Overlays().Remove(object)
	}
}

func addFromCanvas(objects ...fyne.CanvasObject) {
	for _, object := range objects {
		mainWindow.Canvas().Overlays().Add(object)
	}
}

func showImageInModal(img64 string) {
	img, err := base64.StdEncoding.DecodeString(img64)
	if err != nil {
		log.Printf("Error decoding base64 image: %v", err)
		return
	}

	imgDecompressed, err := decompressData(img)
	if err != nil {
		log.Printf("Error decompressing image data: %v", err)
		return
	}

	newImg := canvas.NewImageFromResource(fyne.NewStaticResource("image", imgDecompressed))
	if newImg == nil {
		log.Println("newImg is nil")
		return
	}
	newImg.FillMode = canvas.ImageFillContain

	imgWidth := 500
	imgHeight := (newImg.MinSize().Height * float32(imgWidth)) / newImg.MinSize().Width

	tappableImg := NewImageButtonFromFile(newImg, func() {}, float32(imgWidth), imgHeight)
	tappableImg.Move(fyne.NewPos(mainWindow.Canvas().Size().Width/2-newImg.MinSize().Width/2, mainWindow.Canvas().Size().Height/2-newImg.MinSize().Height/2))

	rightButton := widget.NewButton(">", func() {})
	leftButton := widget.NewButton("<", func() {})

	rightButton.Resize(fyne.NewSize(60, 60))
	leftButton.Resize(fyne.NewSize(60, 60))

	rightButton.Move(fyne.NewPos(mainWindow.Canvas().Size().Width-60, mainWindow.Canvas().Size().Height/2-30))
	leftButton.Move(fyne.NewPos(0, mainWindow.Canvas().Size().Height/2-30))

	overlay := canvas.NewRectangle(&color.RGBA{0, 0, 0, 128})
	windowSize := mainWindow.Canvas().Size()
	overlay.Resize(fyne.NewSize(windowSize.Width, windowSize.Height))

	modal := container.NewWithoutLayout(overlay)

	rightButton.OnTapped = func() {
		askForFullImageForModal(currentIndexOnModal + 1)
		removeFromCanvas(modal, tappableImg, rightButton, leftButton)
	}

	leftButton.OnTapped = func() {
		if currentIndexOnModal == 1 {
			return
		}
		askForFullImageForModal(currentIndexOnModal - 1)
		removeFromCanvas(modal, tappableImg, rightButton, leftButton)
	}
	//FOR SOME REASON, ONLY WORKS 1 BUTTON UNLESS I ADD THEM TO A CONTAINER WTF
	buttons := container.NewWithoutLayout(rightButton, leftButton)

	addFromCanvas(modal, tappableImg, buttons)

	mainWindow.Canvas().SetOnTypedKey(func(keyEvent *fyne.KeyEvent) {
		if keyEvent.Name == fyne.KeyEscape {
			removeFromCanvas(modal, tappableImg, rightButton, leftButton)

			mainWindow.Canvas().SetOnTypedKey(func(keyEvent *fyne.KeyEvent) {
			})
		}
	})
	tappableImg.OnTapped = func() {
		removeFromCanvas(modal, tappableImg, rightButton, leftButton)
	}
	log.Println("showImageInModal completed")
}

func askForFullImageForModal(index int) {
	if !ws.isConnectionAlive() {
		log.Println("WebSocket connection is not alive")
		return
	}

	log.Println("Requesting full image")
	ws.sendData(fmt.Sprintf("askFullImage//%d", index-1))
	currentIndexOnModal = index
}
