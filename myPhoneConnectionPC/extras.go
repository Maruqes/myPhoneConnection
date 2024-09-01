package main

import (
	"fmt"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/go-vgo/robotgo"
	"github.com/micmonay/keybd_event"
)

type Extras struct {
	kb keybd_event.KeyBonding
}

func (extras *Extras) leftPowerpoint(s string) {
	// Select keys to be pressed
	extras.kb.SetKeys(keybd_event.VK_LEFT)

	// Set shift to be pressed
	extras.kb.HasSHIFT(false)

	// Or you can use Press and Release
	extras.kb.Press()
	time.Sleep(1 * time.Millisecond)
	extras.kb.Release()
}

func (extras *Extras) rightPowerpoint(s string) {
	// Select keys to be pressed
	extras.kb.SetKeys(keybd_event.VK_RIGHT)

	// Set shift to be pressed
	extras.kb.HasSHIFT(false)

	// Or you can use Press and Release
	extras.kb.Press()
	time.Sleep(1 * time.Millisecond)
	extras.kb.Release()
}

func (extras *Extras) mouseMoveEvent(s string) {
	x, err := strconv.Atoi(strings.Split(s, "|")[0])
	if err != nil {
		fmt.Println(err)
		return
	}
	y, err := strconv.Atoi(strings.Split(s, "|")[1])
	if err != nil {
		fmt.Println(err)
		return
	}
	robotgo.MoveRelative(x, y)

}

func (extras *Extras) mouseEvent(s string) {
	if s == "right_click" {
		robotgo.Click("right")
	} else if s == "left_click" {
		robotgo.Click("left")
	}
}

func (extras *Extras) initKeys() {
	var err error

	extras.kb, err = keybd_event.NewKeyBonding()
	if err != nil {
		panic(err)
	}

	// For linux, it is very important to wait 2 seconds
	if runtime.GOOS == "linux" {
		time.Sleep(2 * time.Second)
	}
	// Here, the program will generate "ABAB" as if they were pressed on the keyboard.
}
