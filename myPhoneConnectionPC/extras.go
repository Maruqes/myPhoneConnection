package main

import (
	"fmt"
	"log"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/go-vgo/robotgo"
	"github.com/micmonay/keybd_event"
	"github.com/shirou/gopsutil/v3/process"
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

func (extras *Extras) askForProcesses(s string) {
	//get all processes
	processes, err := process.Processes()
	if err != nil {
		log.Println("Error fetching processes:", err)
		return
	}
	//divide processes with //||// and PID from name with &%&
	res := ""
	for i := 0; i < len(processes); i++ {

		owner, err := processes[i].Username()
		if err != nil {
			log.Println("Error fetching process owner:", err)
			continue
		}

		if owner == "root" {
			continue
		}

		name, err := processes[i].Name()
		if err != nil {
			log.Println("Error fetching process name:", err)
			continue
		}

		pid := processes[i].Pid

		process := name + "&%&" + strconv.Itoa(int(pid))
		res += process + "//||//"
	}

	ws.sendData("setNewProcesses", res)
	log.Println("Processes sent")
}

func (extras *Extras) killProcess(s string) {
	pid, err := strconv.Atoi(s)
	if err != nil {
		log.Println("Error converting PID to int:", err)
		return
	}

	proc, err := process.NewProcess(int32(pid))
	if err != nil {
		log.Println("Error fetching process:", err)
		return
	}

	err = proc.Kill()
	if err != nil {
		log.Println("Error killing process:", err)
		return
	}
}
