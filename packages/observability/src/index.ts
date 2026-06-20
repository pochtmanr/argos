// /Users/roman/Developer/iosbrowser/packages/observability/src/index.ts
export type LogLevel = "debug" | "info" | "warn" | "error";

export type LogEvent = {
  level: LogLevel;
  message: string;
  context?: Record<string, unknown>;
  timestamp?: string;
};

export function createLogger(service: string) {
  return {
    log(event: LogEvent): void {
      const payload = {
        service,
        level: event.level,
        message: event.message,
        context: event.context ?? {},
        timestamp: event.timestamp ?? new Date().toISOString()
      };
      process.stdout.write(`${JSON.stringify(payload)}\n`);
    },
    info(message: string, context?: Record<string, unknown>): void {
      this.log({ level: "info", message, context });
    },
    error(message: string, context?: Record<string, unknown>): void {
      this.log({ level: "error", message, context });
    }
  };
}
