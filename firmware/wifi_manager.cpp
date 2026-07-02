#include "wifi_manager.h"
#include "storage.h"

unsigned long lastWifiCheck = 0;

void WiFiManagerClass::begin() {
    String ssid, pass;
    Storage.loadWifi(ssid, pass);
    
    WiFi.mode(WIFI_STA);
    if (ssid.length() > 0) {
        WiFi.begin(ssid.c_str(), pass.c_str());
    }
}

void WiFiManagerClass::loop() {
    if (millis() - lastWifiCheck > 10000) {
        lastWifiCheck = millis();
        if (WiFi.status() != WL_CONNECTED) {
            String ssid, pass;
            Storage.loadWifi(ssid, pass);
            if (ssid.length() > 0 && WiFi.status() != WL_DISCONNECTED) {
                WiFi.begin(ssid.c_str(), pass.c_str());
            }
        }
    }
}

bool WiFiManagerClass::connected() {
    return WiFi.status() == WL_CONNECTED;
}

WiFiManagerClass WiFiManager;
