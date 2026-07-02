window.readESPSerialParameters = async function(secretToSet) {
  if (!navigator.serial) {
    throw new Error("Web Serial API is not supported in your browser.");
  }
  
  let port;
  try {
    port = await navigator.serial.requestPort();
  } catch (e) {
    throw new Error("Port selection cancelled or failed.");
  }

  const baudRatesToTry = [115200, 9600, 74880, 57600];
  let jsonResult = null;
  let successBaudRate = null;
  
  const startTime = Date.now();
  const maxDuration = 60000; // 1 minute

  while (Date.now() - startTime < maxDuration && !jsonResult) {
    for (const baud of baudRatesToTry) {
      if (Date.now() - startTime >= maxDuration) break;
      
      try {
        await port.open({ baudRate: baud });
        
        // Write command directly to writer
        const encoder = new TextEncoder();
        const writer = port.writable.getWriter();
        await writer.write(encoder.encode('{"command":"device_info"}\n'));
        writer.releaseLock();
        
        // Read response directly from reader
        const decoder = new TextDecoder();
        const reader = port.readable.getReader();
        let buffer = "";
        let foundInfo = null;
        
        const readTimeout = new Promise((resolve) => setTimeout(() => resolve("TIMEOUT"), 2500));
        
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
                    if (parsed["macAddress"]) {
                      return parsed;
                    }
                  } catch(e) {}
                }
              }
            }
          } catch(e) {}
          return null;
        };
        
        const result = await Promise.race([readLoop(), readTimeout]);
        
        if (result && result !== "TIMEOUT") {
          foundInfo = result;
        }
        
        // Safe Cleanup: cancel reading first, release lock, then close
        await reader.cancel().catch(()=>{});
        reader.releaseLock();
        await port.close();

        if (foundInfo) {
          jsonResult = foundInfo;
          successBaudRate = baud;
          break;
        }
      } catch (e) {
        try {
          await port.close().catch(()=>{});
        } catch(err) {}
      }
    }
  }

  if (!jsonResult) {
    throw new Error("Could not communicate with the device. Tried multiple baud rates for 1 minute. Please check your wiring and ensure the ESP32 is powered.");
  }

  if (secretToSet) {
    await port.open({ baudRate: successBaudRate });
    const encoder = new TextEncoder();
    const writer = port.writable.getWriter();
    await writer.write(encoder.encode(JSON.stringify({ command: "set_secret", secret: secretToSet }) + '\n'));
    writer.releaseLock();
    
    const decoder = new TextDecoder();
    const reader = port.readable.getReader();
    let buffer = "";
    
    const readTimeout = new Promise((resolve) => setTimeout(() => resolve("TIMEOUT"), 5000));
    
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

    if (secretResult === "TIMEOUT" || !secretResult) {
      throw new Error("Failed to set secret on the device.");
    }
  }

  return JSON.stringify(jsonResult);
};

window.flashESPFirmware = async function(base64Data, updateProgressCallback) {
  if (!navigator.serial) throw new Error("Web Serial API not supported");
  
  // Dynamically import esptool-js bundle (ES Module) when needed
  const esptoolModule = await import('https://unpkg.com/esptool-js/bundle.js');
  const ESPLoader = esptoolModule.ESPLoader;
  const Transport = esptoolModule.Transport;
  
  let port;
  let transport;
  try {
    port = await navigator.serial.requestPort();
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
    
    await esploader.main_fn();
    await esploader.flash_id();
    
    const fileArrayForEsptool = [{ data: binaryString, address: 0x0 }];
    
    await esploader.write_flash({
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
      await transport.disconnect();
    }
  }
};
