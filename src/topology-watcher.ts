import socketIO from "socket.io";

export async function topologyWatcher(db, server, socketOptions = {}) {
  console.log("Starting topology watcher");
  // Watches for PG events
  const io = socketIO(server, socketOptions);
  io.on("connection", (socket: any) => {
    console.log("Client connected");
    console.log(socket.handshake);
    socket.on("disconnect", () => {
      console.log("Client disconnected");
    });
  });

  // Listen for data
  const conn = await db.connect({ direct: true });
  conn.client.on("notification", (message) => {
    const data = JSON.parse(message.payload);
    io.emit("topology", data);
    const v = JSON.stringify(data, null, 2);
    console.log("\n");
    console.log(`Emitting topology change event: ${v}`);
    // The payload isn't used for anything right now...
  });

  setInterval(() => {
    io.emit("server-heartbeat", "Hello!");
  }, 2000);

  conn.none("LISTEN $1~", "topology");
}
