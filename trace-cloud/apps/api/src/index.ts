import "dotenv/config";
import app from "./app";
import { config } from "./config";
import { prisma } from "./lib/prisma";

async function main() {
  // Verify DB connection
  await prisma.$connect();
  console.log("[api] Database connected");

  const server = app.listen(config.PORT, () => {
    console.log(`[api] Trace Cloud API running on http://localhost:${config.PORT}`);
    console.log(`[api] Environment: ${config.NODE_ENV}`);
  });

  const shutdown = async () => {
    console.log("[api] Shutting down...");
    server.close(async () => {
      await prisma.$disconnect();
      process.exit(0);
    });
  };

  process.on("SIGTERM", shutdown);
  process.on("SIGINT", shutdown);
}

main().catch((err) => {
  console.error("[api] Fatal startup error:", err);
  process.exit(1);
});
