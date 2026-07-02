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

  for (const baud of baudRatesToTry) {
    try {
      await port.open({ baudRate: baud });
      
      const textEncoder = new TextEncoderStream();
      const writableStreamClosed = textEncoder.readable.pipeTo(port.writable);
      const writer = textEncoder.writable.getWriter();
      await writer.write('{"command":"device_info"}\\n');
      writer.releaseLock();
      
      const textDecoder = new TextDecoderStream();
      const readableStreamClosed = port.readable.pipeTo(textDecoder.writable);
      const reader = textDecoder.readable.getReader();
      
      let buffer = "";
      let foundInfo = null;
      
      const readTimeout = new Promise((resolve) => setTimeout(() => resolve("TIMEOUT"), 3000));
      
      const readLoop = async () => {
        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          if (value) {
            buffer += value;
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
        return null;
      };
      
      const result = await Promise.race([readLoop(), readTimeout]);
      
      if (result && result !== "TIMEOUT") {
        foundInfo = result;
      }
      
      await reader.cancel().catch(()=>{});
      await readableStreamClosed.catch(()=>{});
      await writer.close().catch(()=>{});
      await writableStreamClosed.catch(()=>{});
      await port.close();

      if (foundInfo) {
        jsonResult = foundInfo;
        successBaudRate = baud;
        break;
      }
    } catch (e) {
      if (port && port.readable) {
        await port.close().catch(()=>{});
      }
    }
  }

  if (!jsonResult) {
    throw new Error("Could not communicate with the device. Tried baud rates: " + baudRatesToTry.join(", "));
  }

  if (secretToSet) {
    await port.open({ baudRate: successBaudRate });
    const textEncoder = new TextEncoderStream();
    const writableStreamClosed = textEncoder.readable.pipeTo(port.writable);
    const writer = textEncoder.writable.getWriter();
    await writer.write(JSON.stringify({ command: "set_secret", secret: secretToSet }) + '\\n');
    writer.releaseLock();
    
    const textDecoder = new TextDecoderStream();
    const readableStreamClosed = port.readable.pipeTo(textDecoder.writable);
    const reader = textDecoder.readable.getReader();
    
    let buffer = "";
    const readTimeout = new Promise((resolve) => setTimeout(() => resolve("TIMEOUT"), 5000));
    
    const readLoop = async () => {
      while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        if (value) {
          buffer += value;
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
      return null;
    };
    
    const secretResult = await Promise.race([readLoop(), readTimeout]);
    
    await reader.cancel().catch(()=>{});
    await readableStreamClosed.catch(()=>{});
    await writer.close().catch(()=>{});
    await writableStreamClosed.catch(()=>{});
    await port.close();

    if (secretResult === "TIMEOUT" || !secretResult) {
      throw new Error("Failed to set secret on the device.");
    }
  }

  return JSON.stringify(jsonResult);
};

window.flashESPFirmware = async function(base64Data, updateProgressCallback) {
  if (!navigator.serial) throw new Error("Web Serial API not supported");
  let port;
  let transport;
  try {
    port = await navigator.serial.requestPort();
    transport = new esptooljs.Transport(port);
    
    // esptool-js expects the fileArray data to be binary string format
    const binaryString = window.atob(base64Data);
    
    const esploader = new esptooljs.ESPLoader({
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
