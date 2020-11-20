import socketIO from "socket.io";

export async function topologyWatcher(db, server) {
  console.log("Starting topology watcher");
  // Watches for PG events
  const io = socketIO(server);
  io.on("connection", () => console.log("Client connected"));

  // Listen for data
  const conn = await db.connect({ direct: true });
  conn.client.on("notification", (message) => {
    const data = JSON.parse(message.payload);
    io.emit("topology", data);
    console.log(`Emitting topology change event: ${data.payload}`);
    // The payload isn't used for anything right now...
  });

  setInterval(() => {
    io.emit("server-heartbeat", "Hello!");
  }, 2000);

  conn.none("LISTEN $1~", "topology");
}
