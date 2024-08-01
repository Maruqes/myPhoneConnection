package main

import (
	"encoding/base64"
	"fmt"
	"image/color"
	"log"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/widget"
	"github.com/getlantern/systray"
)

var (
	mainApp        fyne.App
	mainWindow     fyne.Window
	imageGallery   *fyne.Container
	cacheImages    []*ImageButton
	imgOffset      int
	numberOfImages int
	allImagesLen   int
	loadingPhotos  bool
	mutex          sync.Mutex
)

var (
	imgNumberFooter    *widget.Label
	maxImgNumberFooter *widget.Label
)

const IMAGES_WIDTH = 150

// func resizeImage(img []byte, width uint) ([]byte, error) {
// 	imgDecoded, _, err := image.Decode(bytes.NewReader(img))
// 	if err != nil {
// 		return nil, err
// 	}
// 	imgWidth := imgDecoded.Bounds().Dx()
// 	imgHeight := imgDecoded.Bounds().Dy()
// 	log.Println(imgWidth, imgHeight)

// 	dif := float64(width) / float64(imgWidth)
// 	lastHeight := float64(imgHeight) * dif

// 	imgResized := resize.Resize(width, uint(lastHeight), imgDecoded, resize.Lanczos3)
// 	buf := new(bytes.Buffer)
// 	err = jpeg.Encode(buf, imgResized, nil)
// 	if err != nil {
// 		return nil, err
// 	}

// 	return buf.Bytes(), nil
// }

//ao add new images at the start the index get fucked fix that

type ImageButton struct {
	widget.BaseWidget
	Image    *canvas.Image
	OnTapped func()
	index    int
}

func NewImageButtonFromFile(img *canvas.Image, onTapped func(), width float32, heigth float32) *ImageButton {
	button := &ImageButton{Image: img, OnTapped: onTapped}
	button.ExtendBaseWidget(button)
	img.SetMinSize(fyne.NewSize(width, heigth)) // Set image size explicitly
	return button
}

func (b *ImageButton) CreateRenderer() fyne.WidgetRenderer {
	return widget.NewSimpleRenderer(b.Image)
}

func (b *ImageButton) Tapped(ev *fyne.PointEvent) {
	if b.OnTapped != nil {
		b.OnTapped()
	}
}

func showVideoInModal(vid64 string) {
	// vid, err := base64.StdEncoding.DecodeString(vid64)
	// if err != nil {
	// 	log.Printf("Error decoding base64 image: %v", err)
	// 	return
	// }

	// vidDecompressed, err := decompressData(vid)
	// if err != nil {
	// 	log.Printf("Error decompressing image data: %v", err)
	// 	return
	// }

	//vidDecompressed
	videoHTML := `<iframe width="560" height="315" src="https://www.youtube.com/embed/dQw4w9WgXcQ" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>`
	webView := widget.NewLabel(videoHTML)
    content := container.NewScroll(webView)
	mainWindow.Canvas().Overlays().Add(content)

	log.Println("showImageInModal completed")
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

	mainWindow.Canvas().Overlays().Add(tappableImg)

	overlay := canvas.NewRectangle(&color.RGBA{0, 0, 0, 128})
	windowSize := mainWindow.Canvas().Size()
	overlay.Resize(fyne.NewSize(windowSize.Width, windowSize.Height))

	modal := container.NewWithoutLayout(overlay)

	mainWindow.Canvas().Overlays().Add(modal)
	mainWindow.Canvas().Overlays().Add(tappableImg)

	tappableImg.OnTapped = func() {
		mainWindow.Canvas().Overlays().Remove(modal)
		mainWindow.Canvas().Overlays().Remove(tappableImg)
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
}

func updateUI() {
	imgNumberFooter.SetText(strconv.Itoa(imgOffset))
	maxImgNumberFooter.SetText(strconv.Itoa(numberOfImages))

	imageGallery.Refresh()
	imgNumberFooter.Refresh()
	maxImgNumberFooter.Refresh()

}

func processImage(img64 string) (*canvas.Image, error) {
	img, err := base64.StdEncoding.DecodeString(img64)
	if err != nil {
		log.Printf("Error decoding base64 image: %v", err)
		return nil, err
	}

	imgDecompressed, err := decompressData(img)
	if err != nil {
		log.Printf("Error decompressing image data: %v", err)
		return nil, err
	}

	// imgResized, _ := resizeImage(imgDecompressed, IMAGES_WIDTH)

	mutex.Lock()
	numberOfImages++
	allImagesLen += len(imgDecompressed)
	mutex.Unlock()

	newImg := canvas.NewImageFromResource(fyne.NewStaticResource("image", imgDecompressed))
	if newImg == nil {
		log.Println("newImg is nil")
		return nil, fmt.Errorf("newImg is nil")
	}
	newImg.FillMode = canvas.ImageFillContain
	newImg.SetMinSize(fyne.NewSize(IMAGES_WIDTH, IMAGES_WIDTH)) //used IMAGES_WIDTH on both width and height to make it square

	return newImg, nil
}

func addCacheImages(imgBytes string, first bool) {
	lastIndex := 0
	if len(cacheImages) > 0 {
		lastIndex = cacheImages[len(cacheImages)-1].index
	}

	log.Println("addCacheImages started")
	imgArr := strings.Split(strings.TrimSuffix(imgBytes, "//DIVIDER//"), "//DIVIDER//")
	for i, img64 := range imgArr {
		newImg, err := processImage(img64)
		if err != nil {
			continue
		}

		tappableImg := NewImageButtonFromFile(newImg, func() {}, IMAGES_WIDTH, IMAGES_WIDTH)
		tappableImg.index = i + lastIndex + 1
		tappableImg.OnTapped = func() {
			log.Printf("Tapped image %d", tappableImg.index)
			askForFullImageForModal(tappableImg.index)
		}

		mutex.Lock()
		if first {
			cacheImages = append([]*ImageButton{tappableImg}, cacheImages...)
		} else {
			cacheImages = append(cacheImages, tappableImg)
		}
		mutex.Unlock()
	}
	log.Println("addCacheImages completed")
	updateUI()
	// addNewImages()
}

func calculateImagesToAdd(batch int, length int) []fyne.CanvasObject {
	if imgOffset+batch > len(cacheImages) {
		batch = len(cacheImages) - imgOffset
	}

	if imgOffset+batch < 0 {
		batch = -imgOffset
	}

	imgOffset += batch

	imagesToAdd := make([]fyne.CanvasObject, 0, length)
	for i := imgOffset; i < imgOffset+length; i++ {
		if i >= len(cacheImages) {
			break
		}
		imagesToAdd = append(imagesToAdd, cacheImages[i])
	}
	return imagesToAdd
}

func showNewImagesArray(batch int, length int) {
	mutex.Lock()
	defer mutex.Unlock()

	if loadingPhotos {
		log.Println("Loading photos is already in progress")
		return
	}

	if (imgOffset+batch >= len(cacheImages)) || imgOffset+batch < 0 {
		return
	}

	loadingPhotos = true
	defer func() { loadingPhotos = false }()

	log.Println("showNewImagesArray started")
	imageGallery.RemoveAll()

	imagesToAdd := calculateImagesToAdd(batch, length)

	imageGallery.Objects = append(imageGallery.Objects, imagesToAdd...)

	updateUI()
	log.Println("showNewImagesArray completed")
}
func loadCurrentImages() {
	showNewImagesArray(0, 12)
}

func loadRightImages() {
	showNewImagesArray(12, 12)
}

func loadLeftImages() {
	showNewImagesArray(-12, 12)
}

func addNewImages() {
	if !ws.isConnectionAlive() {
		log.Println("WebSocket connection is not alive")
		return
	}

	log.Println("Requesting new images")
	ws.sendData("askImages")
}

func addFIRSTImages() {
	if !ws.isConnectionAlive() {
		log.Println("WebSocket connection is not alive")
		return
	}

	log.Println("Requesting new images")
	ws.sendData("firstImages")
}

func createUI() {
	imgOffset = 0
	loadingPhotos = false

	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)

	mainApp = app.New()
	mainWindow = mainApp.NewWindow("Fyne App with Systray")
	imageGallery = container.NewAdaptiveGrid(3)

	button := widget.NewButton("Get Image Info", func() {
		mutex.Lock()
		defer mutex.Unlock()
		log.Printf("number_of_images: %d", numberOfImages)
		log.Printf("all_images_len: %d", allImagesLen)
		log.Printf("cacheImages: %d", len(cacheImages))
	})

	buttonLeft := widget.NewButton("Load Left Images", func() {
		loadLeftImages()
	})

	buttonRight := widget.NewButton("Load Right Images", func() {
		loadRightImages()
	})

	buttonCache := widget.NewButton("Cache Images", func() {
		go addNewImages()
	})

	imgNumberFooter = widget.NewLabel(strconv.Itoa(imgOffset))
	maxImgNumberFooter = widget.NewLabel(strconv.Itoa(numberOfImages))

	footer := container.New(layout.NewHBoxLayout(), layout.NewSpacer(), imgNumberFooter, layout.NewSpacer(), maxImgNumberFooter, layout.NewSpacer())

	content := container.NewVBox(
		button,
		buttonLeft,
		buttonRight,
		buttonCache,
		imageGallery,
		layout.NewSpacer(), // Adds space between the main content and footer
		footer,
	)

	mainWindow.SetContent(content)
	mainWindow.SetCloseIntercept(func() {
		mainWindow.Hide()
	})

	go func() {
		systray.Run(onReady, onExit)
	}()

	mainWindow.Resize(fyne.NewSize(1000, 800))
	mainWindow.ShowAndRun()
}

func onReady() {
	systray.SetIcon(iconData)
	systray.SetTitle("Fyne App")
	systray.SetTooltip("Fyne App Running in Background")

	mShow := systray.AddMenuItem("Show", "Show the application window")
	mQuit := systray.AddMenuItem("Quit", "Quit the application")

	go func() {
		for {
			select {
			case <-mShow.ClickedCh:
				mainWindow.Show()
			case <-mQuit.ClickedCh:
				mainApp.Quit()
			}
		}
	}()
}

func onExit() {
	log.Println("Systray exiting")
}

var iconData = []byte{
	0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
	0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x40, 0x08, 0x06, 0x00, 0x00, 0x00, 0xAA, 0x69, 0x71,
	0xDE, 0x00, 0x00, 0x01, 0x1E, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0xED, 0x9A, 0x41, 0x0E, 0x83,
	0x30, 0x0C, 0x04, 0x9B, 0xAA, 0xFF, 0xFF, 0x72, 0x38, 0x21, 0xE5, 0x50, 0x10, 0x92, 0x77, 0x3D,
	0x12, 0xD9, 0xB9, 0xB6, 0xC4, 0x9B, 0x89, 0x53, 0x54, 0xC2, 0x98, 0x73, 0xCE, 0xCF, 0xC6, 0x7C,
	0xE9, 0x00, 0x34, 0x11, 0x40, 0x07, 0xA0, 0x89, 0x00, 0x3A, 0x00, 0x4D, 0x04, 0xD0, 0x01, 0x68,
	0x22, 0x80, 0x0E, 0x40, 0x13, 0x01, 0x74, 0x00, 0x9A, 0x08, 0xA0, 0x03, 0xD0, 0x44, 0x00, 0x1D,
	0x80, 0x26, 0x02, 0xE8, 0x00, 0x34, 0x11, 0x40, 0x07, 0xA0, 0x89, 0x00, 0x3A, 0x00, 0x4D, 0x04,
	0xD0, 0x01, 0x68, 0x22, 0x80, 0x0E, 0x40, 0x13, 0x01, 0x74, 0x00, 0x9A, 0x08, 0xA0, 0x03, 0xD0,
	0x44, 0x00, 0x1D, 0x80, 0x26, 0x02, 0xE8, 0x00, 0x34, 0x11, 0x40, 0x07, 0xA0, 0x89, 0x00, 0x3A,
	0x00, 0x4D, 0x04, 0xD0, 0x01, 0x68, 0x22, 0x80, 0x0E, 0x40, 0x13, 0x01, 0x74, 0x00, 0x9A, 0x08,
	0xA0, 0x03, 0xD0, 0x44, 0x00, 0x1D, 0x80, 0x26, 0x02, 0xE8, 0x00, 0x34, 0x11, 0x40, 0x07, 0xA0,
	0x89, 0x00, 0x3A, 0x00, 0x4D, 0x04, 0xD0, 0x01, 0x68, 0x22, 0x80, 0x0E, 0x40, 0x13, 0x01, 0x74,
	0x00, 0x9A, 0x08, 0xA0, 0x03, 0xD0, 0x44, 0x00, 0x1D, 0x80, 0x26, 0x02, 0xE8, 0x00, 0x34, 0x11,
	0x40, 0x07, 0xA0, 0x89, 0x00, 0x3A, 0x00, 0x4D, 0x04, 0xD0, 0x01, 0x68, 0x22, 0x80, 0x0E, 0x40,
	0x13, 0x01, 0x74, 0x00, 0x9A, 0x08, 0xA0, 0x03, 0xD0, 0x44, 0x00, 0x1D, 0x80, 0x26, 0x02, 0xE8,
	0x00, 0x34, 0x11, 0x40, 0x07, 0xA0, 0x89, 0x00, 0x3A, 0x00, 0x4D, 0x04, 0xD0, 0x01, 0x68, 0x22,
	0x80, 0x0E, 0x40, 0x13, 0x01, 0x74, 0x00, 0x9A, 0x08, 0xA0, 0x03, 0xD0, 0x44, 0x00, 0x1D, 0x80,
	0x26, 0x02, 0xE8, 0x00, 0x34, 0x11, 0x40, 0x07, 0xA0, 0x89, 0x00, 0x3A, 0x00, 0x4D, 0x04, 0xD0,
	0x01, 0x68, 0x22, 0x80, 0x0E, 0x40, 0x13, 0x01, 0x74, 0x00, 0x9A, 0x08, 0xA0, 0x03, 0xD0, 0x44,
	0x00, 0x1D, 0x80, 0x26, 0x02, 0xE8, 0x00, 0x34, 0x11, 0x40, 0x07, 0xA0, 0x89, 0x00, 0x3A, 0x00,
	0x4D, 0x04, 0xD0, 0x01, 0x68, 0x22, 0x80, 0x0E, 0x40, 0x13, 0x01, 0x74, 0x00, 0x9A, 0x08, 0xA0,
	0x03, 0xD0, 0x44, 0x00, 0x1D, 0x80, 0x26, 0x02, 0xE8, 0x00, 0x34, 0x11, 0x40, 0x07, 0xA0, 0x89,
	0x00, 0x3A, 0x00, 0x4D, 0x04, 0xD0, 0x01, 0x68, 0x22}
