FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libfontconfig1 libx11-6 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY build/server/ /app/
RUN chmod +x /app/MiniRushServer.x86_64
ENTRYPOINT ["/app/MiniRushServer.x86_64", "--headless", "--", "--server"]
