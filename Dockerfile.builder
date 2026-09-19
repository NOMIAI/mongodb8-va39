ARG MONGO_BASE=6z3t2uwtxhu3hk.xuanyuan.run/library/mongo:8.0@sha256:4968f22d0c6c10ef29952f3e807f62872ba22b3312f25803564fbfc08255efc2
FROM --platform=linux/arm64 ${MONGO_BASE}
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl git python3 python3-venv python3-requests \
    build-essential libssl-dev libcurl4-openssl-dev liblzma-dev pkg-config unzip zip \
    && rm -rf /var/lib/apt/lists/*
ENV HOME=/root
ENV PATH=/root/.local/bin:$PATH
WORKDIR /src/mongo
ENTRYPOINT ["/bin/bash", "/build-tools/scripts/compile.sh"]
