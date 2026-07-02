#include "servo_manager.h"
#include "config.h"

void ServoManagerClass::begin() {
    pinMode(SERVO_PIN, OUTPUT);
    digitalWrite(SERVO_PIN, LOW);
}

void ServoManagerClass::feed(uint8_t quantity) {
    for (int q = 0; q < quantity; q++) {
        for (int i = 0; i < 50; i++) {
            digitalWrite(SERVO_PIN, HIGH);
            delayMicroseconds(2400);
            digitalWrite(SERVO_PIN, LOW);
            delayMicroseconds(17600);
        }
        delay(500);
        for (int i = 0; i < 50; i++) {
            digitalWrite(SERVO_PIN, HIGH);
            delayMicroseconds(544);
            digitalWrite(SERVO_PIN, LOW);
            delayMicroseconds(19456);
        }
        delay(500);
    }
}

void ServoManagerClass::calibrate() {
    feed(1);
}

ServoManagerClass ServoManager;
