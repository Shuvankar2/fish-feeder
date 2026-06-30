window.readESPSerialParameters = async function() {
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
              if (parsed.deviceId || parsed.macAddress) {
                jsonResult = parsed;
                break;
              }
            } catch(e) {
              // ignore parse errors, maybe we haven't received the full JSON yet
            }
          }
        }
      }
    };
    
    const result = await Promise.race([readLoop(), readTimeout]);
    
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

    if (result === "TIMEOUT") throw new Error("Timeout reading from device over serial.");
    if (!jsonResult) throw new Error("Could not read valid JSON parameters from the device.");

    return JSON.stringify(jsonResult);
  } catch (e) {
    throw new Error(e.message || e.toString());
  }
};
