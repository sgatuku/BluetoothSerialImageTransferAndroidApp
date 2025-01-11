# androidesp32cambtapp

A simple Flutter android application that can connect to a bluetooth device
that streams images periodically over Bluetooth Serial. This was tested with an ESP32-CAM board
with a custom application. The ESP32-CAM board used the BluetoothSerial library
https://github.com/hen1227/bluetooth-serial.

This project is built off of the public project:

https://www.youtube.com/watch?v=Fl3tDWzTWk8
https://github.com/0015/ThatProject/tree/master/ESP32_BT_CLASSIC/ESP32CAM_BT_SERIAL

This project updates that project with newer android and flutter dependencies to compile with more recent Android Studio versions. It also adds additional application logic to:
1. Receive and save JPEG images to phone storage
2. Maintain that connection in the background
3. Automatically reconnect if BLE connection is lost


## ESP32 Usage
```
  #include "BluetoothSerial.h"
  #include "esp_bt.h"
  #include "esp_bt_main.h"
  #include "esp_bt_device.h"

  #if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
  #error Bluetooth is not enabled! Please run `make menuconfig` to and enable it
  #endif

  #if !defined(CONFIG_BT_SPP_ENABLED)
  #error Serial Bluetooth not available or not enabled. It is only available for the ESP32 chip.
  #endif

  BluetoothSerial SerialBT;

  void btCallback(esp_spp_cb_event_t event, esp_spp_cb_param_t *param){
    if(event == ESP_SPP_SRV_OPEN_EVT){
      Serial.println("Client Connected!");
    }
    if(event == ESP_SPP_CLOSE_EVT){
      Serial.println("Client Disconnected!");
    }
  }

  esp_err_t connectivity_init() {
    if(!SerialBT.begin("ESP32CAM-CLASSIC-BT")){
      Serial.println("An error occurred initializing Bluetooth");
      return ESP_FAIL;
    }else{
      Serial.println("Bluetooth initialized");
    }

    SerialBT.register_callback(btCallback);
    Serial.println("The device started, now you can pair it with bluetooth");
    
    return ESP_OK;
  }

  void connectivity_wait_for_connection() {
    while(!SerialBT.connected()) {
      // Add delay to reduce polling frequency
      delay(100);
    }
    
    // Wait for START command
    Serial.println("Waiting for START command...");
    String command = "";
    while (true) {
      if (SerialBT.available()) {
        command = SerialBT.readStringUntil('\n');
        command.trim();
        if (command == "START") {
          Serial.println("START command received, proceeding...");
          break;
        }
      }
      delay(100);  // Small delay to prevent tight polling
    }
  }

  esp_err_t connectivity_publish_image(const uint8_t* image, size_t size) {
    Serial.printf("Publishing image of size %d bytes\n", size);
    if (SerialBT.connected()) {
      size_t bytesWritten = SerialBT.write(image, size);
      SerialBT.flush();
      Serial.printf("Image published, size: %d bytes\n", bytesWritten);
    }
    else {
      Serial.println("Bluetooth connection lost");
      return ESP_FAIL;
    }

    return ESP_OK;
  }
  ```
