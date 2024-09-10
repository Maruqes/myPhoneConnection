# myPhoneConnection
This project's idea is to connect your phone to your computer, it is now in development and will be available the first version soon with some basic but persistent features.
## Deployment

### Android 

There are 2 folders in the github repository, one for the PC, other for an android

To deploy this project:

- Run the android version install Flutter at [link](https://docs.flutter.dev/get-started/install)
- Configure VSCode and run the project

You can also just install the apk if it is already launched


### Linux
You should be able to run ```dunstify```/```xdg-open```/```zenity```/```sensors```/```amixer```on your terminal

Clon the repository just run the Makefile with

```
sudo apt install dunst
sudo apt install zenity
sudo apt install lm-sensors
sudo apt install alsa-utils 

cd myPhoneConnectionPC/
make 
```

there is a need to install some packages from apt that will be in this README soon

You can also just run the executable if it is already launched
## Features

- Media Controller
- Clipboard text mirror
- Clipboard Screenshots mirror
- Notification viewer 
- Call Notifier 
- Powerpoint Controller
- Mouse/Keyboard Controller
- Process Controller
- System Monitor

### Protocol
![alt text](https://i.postimg.cc/nr0931gc/logseq-my-Phone-Connection-Protocol.png)

- Full pairing from both devices, once connected, should be paired alone if in the same network
- Full end to end encryption in the pairing protocol
- Should both run in as a background service


### Media Controller
- Let you controll you computer Media with your phone, a notification as simple as other apps 3 buttons (pause/play) (previous) (next)

### Clipboard 
- All text or images (including prints) you take will be sent to you phone clipboard, there is a low chance i will support more things like files etc

### Notification viewer 
- All Notifications on your phone will be sent to your pc and shown, the ones that you can reply on your phone can also be replied on you computer

### Call Notifier
- When you get a call the volume on the computer lowers, if the call start the media is paused, when ended it comes back, and the volume also comes back if u refuse the call

### Powerpoint Controller
- On the phone app there is a page with 2 buttons that can controll the left and right arrows, fowarding controlling powerpoint and others

### Mouse Controller
- On the phone app there is a page with some widgets that can controll your mouse and Keyboard, the keyboard is VERY strict and limited, but does simple work as searching for something on the web, it is not designed to write something long

### Process Controller
- On the phone app there is a page with all processes and a button to update that same page, you can kill that processes

### System Monitor
- Let you monitor you disk ram cpu

## Known bugs
- Some notifications are not being displayed on computer

## TODO
- Make the installer better
- Make it run on windows
- Create a logger for it
- Nextpass.bin worng placed