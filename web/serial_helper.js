window.readESPSerialParameters = async function() {
  if (!navigator.serial) {
    throw new Error("Web Serial API is not supported in your browser.");
  }
  
  const esptoolModule = await import('https://unpkg.com/esptool-js/bundle.js');
  const ESPLoader = esptoolModule.ESPLoader;
  const Transport = esptoolModule.Transport;

  let port = window.selectedESPPort;
  if (!port) {
    try {
      port = await navigator.serial.requestPort();
      window.selectedESPPort = port; // Cache it!
    } catch (e) {
      throw new Error("Port selection cancelled or failed.");
    }
  }

  let transport = new Transport(port);
  let esploader = new ESPLoader({
    transport: transport,
    baudrate: 115200,
    terminal: {
      clean: () => {},
      writeLine: (data) => console.log(data)
    }
  });

  try {
    await esploader.main();
    const mac = await esploader.chip.readMac(esploader);
    if (!mac) {
      throw new Error("Could not read MAC address from the chip.");
    }
    
    const chipName = esploader.chip.CHIP_NAME || "ESP32";
    const cleanMac = mac.toUpperCase();
    const macParts = cleanMac.split(":");
    const serialSuffix = macParts.slice(3).join(""); // last 3 bytes
    const serialNumber = `AQGL-${serialSuffix}`;

    const jsonResult = {
      deviceId: serialNumber,
      macAddress: cleanMac,
      serialNumber: serialNumber,
      chipName: chipName
    };

    return JSON.stringify(jsonResult);
  } catch (e) {
    throw new Error("Failed to connect to ESP32 Bootloader: " + (e.message || e.toString()));
  } finally {
    if (transport) {
      await transport.disconnect().catch(()=>{});
    }
  }
};

window.flashESPFirmware = async function(base64Data, updateProgressCallback) {
  if (!navigator.serial) throw new Error("Web Serial API not supported");
  
  const esptoolModule = await import('https://unpkg.com/esptool-js/bundle.js');
  const ESPLoader = esptoolModule.ESPLoader;
  const Transport = esptoolModule.Transport;
  
  let port = window.selectedESPPort;
  if (!port) {
    try {
      port = await navigator.serial.requestPort();
      window.selectedESPPort = port;
    } catch(e) {
      throw new Error("Port selection cancelled or failed.");
    }
  }
  
  let transport;
  try {
    transport = new Transport(port);
    const binaryString = window.atob(base64Data);
    
    const esploader = new ESPLoader({
      transport: transport,
      baudrate: 115200,
      terminal: {
        clean: () => {},
        writeLine: (data) => console.log(data)
      }
    });
    
    await esploader.main();
    await esploader.flashId();
    
    const fileArrayForEsptool = [{ data: binaryString, address: 0x0 }];
    
    await esploader.writeFlash({
      fileArray: fileArrayForEsptool,
      flashSize: "keep",
      flashMode: "keep",
      flashFreq: "keep",
      eraseAll: false,
      compress: true,
      reportProgress: (fileIndex, written, total) => {
        if (updateProgressCallback) {
           updateProgressCallback(written / total);
        }
      }
    });
    
  } catch(e) {
    throw new Error(e.message || e.toString());
  } finally {
    if (transport) {
      await transport.disconnect().catch(()=>{});
    }
  }
};

window.writeESPSecret = async function(secretToSet) {
  if (!navigator.serial) {
    throw new Error("Web Serial API is not supported in your browser.");
  }
  
  let port = window.selectedESPPort;
  if (!port) {
    try {
      port = await navigator.serial.requestPort();
      window.selectedESPPort = port;
    } catch(e) {
      throw new Error("Port selection cancelled or failed.");
    }
  }

  const baudRatesToTry = [115200, 9600, 74880, 57600];
  let success = false;

  for (const baud of baudRatesToTry) {
    try {
      await port.open({ baudRate: baud });
      const encoder = new TextEncoder();
      const writer = port.writable.getWriter();
      await writer.write(encoder.encode(JSON.stringify({ command: "set_secret", secret: secretToSet }) + '\n'));
      writer.releaseLock();
      
      const decoder = new TextDecoder();
      const reader = port.readable.getReader();
      let buffer = "";
      const readTimeout = new Promise((resolve) => setTimeout(() => resolve("TIMEOUT"), 3000));
      
      const readLoop = async () => {
        try {
          while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            if (value) {
              buffer += decoder.decode(value, { stream: true });
              const start = buffer.indexOf('{');
              const end = buffer.lastIndexOf('}');
              if (start !== -1 && end !== -1 && end > start) {
                try {
                  let candidate = buffer.substring(start, end + 1);
                  let parsed = JSON.parse(candidate);
                  if (parsed["status"] === "ok") {
                    return parsed;
                  }
                } catch(e) {}
              }
            }
          }
        } catch(e) {}
        return null;
      };
      
      const secretResult = await Promise.race([readLoop(), readTimeout]);
      
      await reader.cancel().catch(()=>{});
      reader.releaseLock();
      await port.close();

      if (secretResult && secretResult !== "TIMEOUT") {
        success = true;
        break;
      }
    } catch (e) {
      try {
        await port.close().catch(()=>{});
      } catch(err) {}
    }
  }

  if (!success) {
    throw new Error("Failed to set secret key on the device. Tried multiple baud rates.");
  }
  return "SUCCESS";
};
