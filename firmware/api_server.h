#pragma once
#include <WebServer.h>

class ApiServerClass {
public:
    void begin();
    void loop();
};

extern ApiServerClass ApiServer;
