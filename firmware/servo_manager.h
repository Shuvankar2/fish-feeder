#pragma once
#include <Arduino.h>

class ServoManagerClass {
public:
    void begin();
    void feed(uint8_t quantity);
    void calibrate();
};

extern ServoManagerClass ServoManager;
