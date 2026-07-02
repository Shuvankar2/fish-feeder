#include "api_server.h"
#include "storage.h"
#include "servo_manager.h"
#include "config.h"
#include <ArduinoJson.h>

WebServer server(80);

void handleGetInfo() {
    StaticJsonDocument<200> doc;
    DeviceInfo dev = Storage.loadDevice();
    doc["deviceId"] = dev.deviceId;
    doc["serial"] = dev.serial;
    doc["firmware"] = dev.firmware;
    
    String response;
    serializeJson(doc, response);
    server.send(200, "application/json", response);
}

void handlePostFeed() {
    if (server.hasArg("plain") == false) {
        server.send(400, "text/plain", "Body missing");
        return;
    }
    StaticJsonDocument<100> doc;
    deserializeJson(doc, server.arg("plain"));
    uint8_t qty = doc["quantity"] | 1;
    ServoManager.feed(qty);
    server.send(200, "application/json", "{\"status\":\"success\"}");
}

void handlePostWifi() {
    if (server.hasArg("plain") == false) {
        server.send(400, "text/plain", "Body missing");
        return;
    }
    StaticJsonDocument<200> doc;
    deserializeJson(doc, server.arg("plain"));
    const char* ssid = doc["ssid"];
    const char* pass = doc["password"];
    if (ssid) {
        Storage.saveWifi(ssid, pass ? pass : "");
        server.send(200, "application/json", "{\"status\":\"success\"}");
        delay(1000);
        ESP.restart();
    } else {
        server.send(400, "application/json", "{\"status\":\"error\"}");
    }
}

void ApiServerClass::begin() {
    server.on("/api/device/info", HTTP_GET, handleGetInfo);
    server.on("/api/feed", HTTP_POST, handlePostFeed);
    server.on("/api/wifi", HTTP_POST, handlePostWifi);
    server.begin();
}

void ApiServerClass::loop() {
    server.handleClient();
}

ApiServerClass ApiServer;
