# Module 2: Chrome Dino Game
In this module, we used a LilyGo TTGO T-display ESP32 and breadboarding components (joystick, red LED, pushbutton, and potentiometer dial) to create an interactive device. I re-created the Chrome dino game, where the game controls are physical.

You can read more about my implementation at [this blog article](https://app.notion.com/p/Module-2-Interactive-Devices-Chrome-Dino-Game-40ad5c8d2dcb800eaf9fdbe4115a85a7?source=copy_link), which details how this was implemented, my design process, and technical challenges.

## Project Video
https://github.com/user-attachments/assets/2318299c-0cba-4895-ad7b-41fd1dc46c95
Note: this video is at 1.5x speed. It demonstrates jump/duck, speeding up/down, and the shield.


## Recreating the project

To recreate this project, you will need the following physical components:
-   LilyGo T-Display microcontroller
-   A breadboard
-   A joystick
-   A red LED
-   A pushbutton
-   A potentiometer dial

My code uses Arduino and Processing. Arduino is used to read the physical controls and send their inputs to Processing, which runs and displays the game. Instructions for downloading the [Arduino IDE can be found here](https://support.arduino.cc/hc/en-us/articles/360019833020-Download-and-install-Arduino-IDE). You can download [Processing here](https://processing.org/download/).

### Hardware Setup
To recreate the hardware setup, follow the Fritzing diagram below. Make sure each component is connected to the pin specified in the Arduino sketch.
<img width="1935" height="1308" alt="image" src="https://github.com/user-attachments/assets/4da06cca-a104-4d60-92a2-6818cfa6ffa2" />

### ESP32 Board Setup
1. Download the [Arduino IDE](https://www.arduino.cc/en/software/).
2. Install the [TTGO T-Display driver](https://github.com/Xinyuan-LilyGO/TTGO-T-Display). Make sure that it is the correct `CHxxx Series driver`. On a Mac, you will need to go to `Privacy and Security` in your settings to allow the driver app to install.
3. Install the `tft_espi` by Bodmer library, in `Tools > Manage Libraries`. Click the install button to install.
4. Navigate to the library, in `.../Arduino/libraries/tft_espi`. Open up `User_Setup_Select.h` and comment out the line `#include <User_setup.h>`. Uncomment the line `include <User_Setups/Setup25_TTGO_T_Display.h>`
5. Install the [ESP32 library](https://docs.espressif.com/projects/arduino-esp32/en/latest/installing.html), under `Installing using Arduino IDE`.
6. Set the Arudino upload settings:
`Tools > Boards > esp32 > ESP32 Dev Module`
`Tools > Port > your_port` - on Mac, this should be `wchusb`
`Tools > Upload Speed > 115200`

More detailed instructions can be found [here](https://comsbc3930-fall-2026.notion.site/Lab-1-TFT-Display-903350cc6f0582eabcf38175506b2c68).

### Code
To run the Arduino and Processing code:
1.  Clone this GitHub repository.
2.  Open `Arduino.ino` from the `Arduino` folder in the Arduino IDE.
3.  Select your ESP32 board and port (from above), then upload the sketch.
4.  Close the Arduino Serial Monitor so Processing can access the ESP32.
5.  Open `Processing.pde` from the `Processing` folder in Processing. Keep the `data` folder inside the `Processing` folder so the game can load its images.
6.  While the ESP32 is connected on the USB, click **Run** in Processing to start the game.
7.  If Processing does not connect automatically, set `SERIAL_PORT_INDEX` to the ESP32’s port index shown in the Processing console, then run the sketch again.
