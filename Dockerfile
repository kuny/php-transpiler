FROM debian:bookworm

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       git \
       unzip \
       racket \
    && rm -rf /var/lib/apt/lists/*

CMD ["sh"]
