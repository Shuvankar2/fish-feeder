#pragma once
#include <WiFi.h>

class WiFiManagerClass {
public:
    void begin();
    void loop();
    bool connected();
};

extern WiFiManagerClass WiFiManager;
