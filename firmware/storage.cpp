#include "storage.h"

Preferences prefs;

void StorageClass::begin() {
    prefs.begin("aquaglass", false);
}

void StorageClass::saveDevice(const DeviceInfo& info) {
    prefs.putString("deviceId", info.deviceId);
    prefs.putString("serial", info.serial);
    prefs.putString("mqttHost", info.mqttHost);
    prefs.putString("mqttUser", info.mqttUsername);
    prefs.putString("mqttPass", info.mqttPassword);
    prefs.putString("firmware", info.firmware);
    prefs.putString("secret", info.secret);
}

DeviceInfo StorageClass::loadDevice() {
    DeviceInfo info;
    info.deviceId = prefs.getString("deviceId", "");
    info.serial = prefs.getString("serial", "");
    info.mqttHost = prefs.getString("mqttHost", "broker.hivemq.com");
    info.mqttUsername = prefs.getString("mqttUser", "");
    info.mqttPassword = prefs.getString("mqttPass", "");
    info.firmware = prefs.getString("firmware", "1.0.2");
    info.secret = prefs.getString("secret", "");
    return info;
}

void StorageClass::saveWifi(const String& ssid, const String& pass) {
    prefs.putString("wifi_ssid", ssid);
    prefs.putString("wifi_pass", pass);
}

void StorageClass::loadWifi(String& ssid, String& pass) {
    ssid = prefs.getString("wifi_ssid", "");
    pass = prefs.getString("wifi_pass", "");
}

StorageClass Storage;
