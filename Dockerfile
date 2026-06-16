FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    curl \
    python3 \
    python3-pip \
    sed \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | BINDIR=/usr/local/bin sh

RUN arduino-cli config init && \
    STM32_URL="https://github.com/stm32duino/BoardManagerFiles/raw/main/package_stmicroelectronics_index.json" && \
    arduino-cli core update-index --additional-urls "$STM32_URL" && \
    arduino-cli core install STMicroelectronics:stm32 --additional-urls "$STM32_URL"

WORKDIR /build