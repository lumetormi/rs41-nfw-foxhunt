#!/bin/bash
set -e

cd "$(dirname "$0")"

if [ ! -f "foxhunt.env" ]; then
    echo "❌ Error: foxhunt.env file not found!"
    exit 1
fi

echo "Checking/Building the Docker environment..."
docker build -t rs41-compiler .

export $(grep -v '^#' foxhunt.env | xargs)

echo "Starting firmware compilation inside the container..."
docker run --rm \
  -v "$(pwd)":/build \
  --env-file foxhunt.env \
  rs41-compiler bash -c '
    CONFIG_FILE="./rs41-nfw_sonde-firmware/CONFIG.h"
    
    echo "=== 1. Modifying CONFIG.h values ==="
    sed -i "s/\(constexpr bool foxHuntMode\s*=\).*/\1 $foxHuntMode;/g" $CONFIG_FILE
    sed -i "s/\(constexpr bool foxHuntFmMelody\s*=\).*/\1 $foxHuntFmMelody;/g" $CONFIG_FILE
    sed -i "s/\(constexpr bool foxHuntCwTone\s*=\).*/\1 $foxHuntCwTone;/g" $CONFIG_FILE
    sed -i "s/\(constexpr bool foxHuntMorseMarker\s*=\).*/\1 $foxHuntMorseMarker;/g" $CONFIG_FILE
    sed -i "s/\(constexpr bool foxHuntLowVoltageAdditionalMarker\s*=\).*/\1 $foxHuntLowVoltageAdditionalMarker;/g" $CONFIG_FILE
    
    sed -i "s/\(String foxMorseMsg\s*=\).*/\1 \"$foxMorseMsg\";/g" $CONFIG_FILE
    sed -i "s/\(String foxMorseMsgVbat\s*=\).*/\1 \"$foxMorseMsgVbat\";/g" $CONFIG_FILE
    
    sed -i "s/\(constexpr float\s\+foxHuntFrequency\s*=\).*/\1 $foxHuntFrequency;/g" $CONFIG_FILE
    sed -i "s/\(constexpr uint16_t foxHuntTransmissionDelay\s*=\).*/\1 $foxHuntTransmissionDelay;/g" $CONFIG_FILE
    sed -i "s/\(constexpr int8_t\s\+foxHuntRadioPower\s*=\).*/\1 $foxHuntRadioPower;/g" $CONFIG_FILE
    
    echo "=== 2. Setting board target (FQBN) ==="
    if [ "$pcb_model" = "RSM4x4" ]; then
      FQBN="STMicroelectronics:stm32:GenL4:pnum=GENERIC_L412RBTXP,opt=osstd"
    else
      FQBN="STMicroelectronics:stm32:GenF1:pnum=GENERIC_F100C8TX,opt=oslto"
    fi

    echo "=== 3. Compiling code ==="
    mkdir -p ./output_bin
    arduino-cli compile --fqbn "$FQBN" \
      --build-property "compiler.cpp.extra_flags=-D$pcb_model" \
      --output-dir ./output_bin \
      ./rs41-nfw_sonde-firmware/rs41-nfw_sonde-firmware.ino
'

TIMESTAMP=$(date +'%Y-%m-%d_%H-%M-%S')
CLEAN_FREQ=$(echo "$foxHuntFrequency" | sed 's/[^0-9.]//g')

echo "=== 4. Renaming files locally ==="
cd ./output_bin
for f in *.bin; do
    if [ -f "$f" ] && [[ "$f" != rs41-nfw-* ]]; then
        NEW_NAME="rs41-nfw-${pcb_model}-${CLEAN_FREQ}MHz-${foxHuntRadioPower}_PwrLvl-${TIMESTAMP}.bin"
        sudo mv "$f" "$NEW_NAME"
        sudo chmod 777 "$NEW_NAME"
        echo "✅ Finished firmware: ./output_bin/$NEW_NAME"
    fi
done