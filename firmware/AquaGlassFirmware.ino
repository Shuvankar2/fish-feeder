#include "config.h"
#include "wifi_manager.h"
#include "mqtt_manager.h"
#include "servo_manager.h"
#include "scheduler.h"
#include "storage.h"
#include "api_server.h"
#include "heartbeat.h"
#include <ArduinoJson.h>

String serialBuffer = "";

void setup() {
  Serial.begin(115200);
  delay(200);
  while (Serial.available()) Serial.read();

  Storage.begin();
  ServoManager.begin();
  WiFiManager.begin();
  ApiServer.begin();
  MQTTManager.begin();
  Scheduler.begin();
  Heartbeat.begin();
}

void loop() {
  WiFiManager.loop();
  MQTTManager.loop();
  Scheduler.loop();
  ApiServer.loop();
  Heartbeat.loop();

  while (Serial.available()) {
    char c = Serial.read();
    serialBuffer += c;
    if (c == '\n') {
      handleSerialCommand(serialBuffer);
      serialBuffer = "";
    }
  }
}

void handleSerialCommand(String line) {
  line.trim();
  if (line.length() == 0) return;

  StaticJsonDocument<256> cmd;
  if (deserializeJson(cmd, line)) return;

  const char* command = cmd["command"];
  if (!command) return;

  if (strcmp(command, "device_info") == 0) {
    sendDeviceInfo();
  } else if (strcmp(command, "set_secret") == 0) {
    const char* secret = cmd["secret"];
    if (secret) {
      DeviceInfo dev = Storage.loadDevice();
      dev.secret = secret;
      Storage.saveDevice(dev);
      Serial.println("{\"status\":\"ok\",\"action\":\"set_secret\"}");
    }
  }
}

void sendDeviceInfo() {
  StaticJsonDocument<256> resp;
  String mac = WiFi.macAddress();
  String serial = "AQGL-" + mac.substring(9);

  resp["deviceId"] = serial;
  resp["macAddress"] = mac;
  resp["serialNumber"] = serial;

  serializeJson(resp, Serial);
  Serial.println();
}
