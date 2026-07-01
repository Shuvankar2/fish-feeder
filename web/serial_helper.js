window.readESPSerialParameters = async function(secretToSet) {
  if (!navigator.serial) {
    throw new Error("Web Serial API is not supported in your browser.");
  }
  let port;
  try {
    port = await navigator.serial.requestPort();
    await port.open({ baudRate: 115200 });

    const textEncoder = new TextEncoderStream();
    const writableStreamClosed = textEncoder.readable.pipeTo(port.writable);
    const writer = textEncoder.writable.getWriter();
    await writer.write('{"command":"device_info"}\n');
    writer.releaseLock();

    const textDecoder = new TextDecoderStream();
    const readableStreamClosed = port.readable.pipeTo(textDecoder.writable);
    const reader = textDecoder.readable.getReader();

    let buffer = "";
    let jsonResult = null;
    
    const readTimeout = new Promise((resolve) => setTimeout(() => resolve("TIMEOUT"), 8000));
    
    const readLoop = async (waitForKey) => {
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
              if (parsed[waitForKey]) {
                buffer = ""; // clear buffer for next read
                return parsed;
              }
            } catch(e) {
              // ignore parse errors
            }
          }
        }
      }
      return null;
    };
    
    const result = await Promise.race([readLoop("macAddress"), readTimeout]);
    if (result === "TIMEOUT") throw new Error("Timeout reading device_info from device.");
    if (!result) throw new Error("Could not read valid JSON parameters from the device.");
    jsonResult = result;

    if (secretToSet) {
      const writer2 = textEncoder.writable.getWriter();
      await writer2.write(JSON.stringify({ command: "set_secret", secret: secretToSet }) + '\n');
      writer2.releaseLock();
      
      const secretResult = await Promise.race([readLoop("status"), readTimeout]);
      if (secretResult === "TIMEOUT" || !secretResult || secretResult.status !== "ok") {
        throw new Error("Failed to set secret on the device.");
      }
    }
    
    // Cleanup
    try {
      await reader.cancel();
      await readableStreamClosed.catch(() => {});
      await writer.close();
      await writableStreamClosed.catch(() => {});
      await port.close();
    } catch (e) {
      console.warn("Cleanup error: ", e);
    }


    return JSON.stringify(jsonResult);
  } catch (e) {
    throw new Error(e.message || e.toString());
  }
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
