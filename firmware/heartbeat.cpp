#include "heartbeat.h"
#include "config.h"
#include "wifi_manager.h"
#include <Arduino.h>

unsigned long lastHeartbeat = 0;

void HeartbeatClass::begin() {
    pinMode(LED_PIN, OUTPUT);
}

void HeartbeatClass::loop() {
    if (millis() - lastHeartbeat > HEARTBEAT_INTERVAL) {
        lastHeartbeat = millis();
        digitalWrite(LED_PIN, HIGH);
        delay(100);
        digitalWrite(LED_PIN, LOW);
    }
}

HeartbeatClass Heartbeat;
