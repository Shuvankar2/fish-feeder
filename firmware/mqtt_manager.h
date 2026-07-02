#pragma once

class MQTTManagerClass {
public:
    void begin();
    void loop();
    void publishStatus();
};

extern MQTTManagerClass MQTTManager;
