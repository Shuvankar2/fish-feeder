#pragma once
#include <Arduino.h>
#include <Preferences.h>

struct DeviceInfo {
    String deviceId;
    String serial;
    String mqttHost;
    String mqttUsername;
    String mqttPassword;
    String firmware;
    String secret;
};

class StorageClass {
public:
    void begin();
    void saveDevice(const DeviceInfo& info);
    DeviceInfo loadDevice();
    void saveWifi(const String& ssid, const String& pass);
    void loadWifi(String& ssid, String& pass);
};

extern StorageClass Storage;
