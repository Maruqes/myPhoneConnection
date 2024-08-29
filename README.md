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

Clone the repository just run the Makefile with

```
cd myPhoneConnectionPC/
make 
```

there is a need to install some packages from apt that will be in this README soon

You can also just run the executable if it is already launched
## Features

- Gallery viewer
- Media Controller (from the android control media in PC)
- Clipboard text mirror (from PC to android)
- Clipboard Screenshots mirror (from PC to android)
- Notification viewer (from PC see android notifications)
- Call warning (shows a notification and lowers volume)
- Full pairing from both devices, once connected, should be paired alone if in the same network
- Full encryption from p2p in the pairing protocol
- Should both run in as a background service
## Protocol

![alt text](https://i.postimg.cc/nr0931gc/logseq-my-Phone-Connection-Protocol.png)

## Known bugs
- Devices does not show on the app after some time
- Media notification sometimes does not show all buttons

## TODO
- Something to show if connected and who
- Need a icon for App and change notification labels
- More testing
