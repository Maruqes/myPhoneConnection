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

var modal *fyne.Container

func removeFromCanvas(objects ...fyne.CanvasObject) {
	for _, object := range objects {
		mainWindow.Canvas().Overlays().Remove(object)
	}
}

func addToCanvas(objects ...fyne.CanvasObject) {
	for _, object := range objects {
		mainWindow.Canvas().Overlays().Add(object)
	}
}

func clearCanvas() {
	all_objects := mainWindow.Canvas().Overlays().List()

	for _, object := range all_objects {
		mainWindow.Canvas().Overlays().Remove(object)
	}
}

func createTheModalItself() {
	overlay := canvas.NewRectangle(&color.RGBA{0, 0, 0, 128})
	windowSize := mainWindow.Canvas().Size()
	overlay.Resize(fyne.NewSize(windowSize.Width, windowSize.Height))
	modal = container.NewWithoutLayout(overlay)

	addToCanvas(modal)
}

// if video ends, remove modal crashes
func showVideoInModal2(file string, videoPointer *[]byte) {
	u := storage.NewFileURI(file)
	viewer := video.NewPlayer()
	viewer.Open(u)

	viewer.SetMinSize(fyne.NewSize(800, 600))

	quitButton := widget.NewButton("Quit", func() {
		viewer.Stop()
		clearCanvas()
	})
	downloadButton := widget.NewButton("Download", func() {
		saveVideo(*videoPointer)
	})

	buttons := container.NewCenter(container.NewHBox(downloadButton, quitButton))

	content := container.NewCenter(container.NewVBox(viewer, buttons))
	createTheModalItself()

	content.Move(fyne.NewPos(mainWindow.Canvas().Size().Width/2-content.MinSize().Width/2, mainWindow.Canvas().Size().Height/2-content.MinSize().Height/2))
	addToCanvas(content)
	viewer.Play()

	// Detect ESC key press
	mainWindow.Canvas().SetOnTypedKey(func(keyEvent *fyne.KeyEvent) {
		if keyEvent.Name == fyne.KeyEscape {
			viewer.Stop()
			clearCanvas()
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
	defer os.Remove(file.Name())
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

	log.Println("Video saved successfully in", file.Name())
	showVideoInModal2(file.Name(), &vidDecompressed)
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
	downloadButton := widget.NewButton("Download", func() {
		saveImage(imgDecompressed)
	})

	rightButton.Resize(fyne.NewSize(60, 60))
	leftButton.Resize(fyne.NewSize(60, 60))
	downloadButton.Resize(fyne.NewSize(100, 60))

	rightButton.Move(fyne.NewPos(mainWindow.Canvas().Size().Width-60, mainWindow.Canvas().Size().Height/2-30))
	leftButton.Move(fyne.NewPos(0, mainWindow.Canvas().Size().Height/2-30))
	downloadButton.Move(fyne.NewPos(mainWindow.Canvas().Size().Width/2-50, mainWindow.Canvas().Size().Height-60))

	rightButton.OnTapped = func() {
		clearCanvas()
		askForFullImageForModal(currentIndexOnModal + 1)
	}

	leftButton.OnTapped = func() {
		if currentIndexOnModal == 1 {
			return
		}
		clearCanvas()
		askForFullImageForModal(currentIndexOnModal - 1)
	}
	//FOR SOME REASON, ONLY WORKS 1 BUTTON UNLESS I ADD THEM TO A CONTAINER WTF
	buttons := container.NewWithoutLayout(rightButton, leftButton, downloadButton)

	clearCanvas()
	createTheModalItself()
	addToCanvas(tappableImg, buttons)

	mainWindow.Canvas().SetOnTypedKey(func(keyEvent *fyne.KeyEvent) {
		if keyEvent.Name == fyne.KeyEscape {
			clearCanvas()

			mainWindow.Canvas().SetOnTypedKey(func(keyEvent *fyne.KeyEvent) {
			})
		}
	})
	tappableImg.OnTapped = func() {
		clearCanvas()
	}
	log.Println("showImageInModal completed")
}

func showLowResImageInModal(index int) {
	lowResImage := canvas.NewImageFromResource(cacheImages[index].Image.Resource)

	if lowResImage == nil {
		log.Println("lowResImage is nil")
		return
	}
	lowResImage.FillMode = canvas.ImageFillContain

	imgWidth := 500
	imgHeight := (lowResImage.MinSize().Height * float32(imgWidth)) / lowResImage.MinSize().Width
	lowResImage.SetMinSize(fyne.NewSize(float32(imgWidth), imgHeight))

	lowResImage.Move(fyne.NewPos(mainWindow.Canvas().Size().Width/2-lowResImage.MinSize().Width/2, mainWindow.Canvas().Size().Height/2-lowResImage.MinSize().Height/2))

	addToCanvas(lowResImage)
}

func askForFullImageForModal(index int) {
	if !ws.isConnectionAlive() {
		log.Println("WebSocket connection is not alive")
		return
	}

	log.Println("Requesting full image")
	clearCanvas()
	createTheModalItself()
	showLowResImageInModal(index - 1)
	ws.sendData(fmt.Sprintf("askFullImage//%d", index-1))
	currentIndexOnModal = index
}
