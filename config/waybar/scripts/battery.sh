#!/bin/bash

CAPACITY=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1)
STATUS=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1)

if [ "$CAPACITY" -le 10 ]; then LEVEL="0"
elif [ "$CAPACITY" -le 30 ]; then LEVEL="20"
elif [ "$CAPACITY" -le 50 ]; then LEVEL="40"
elif [ "$CAPACITY" -le 70 ]; then LEVEL="60"
elif [ "$CAPACITY" -le 90 ]; then LEVEL="80"
else LEVEL="100"; fi

if [ "$STATUS" = "Charging" ] || [ "$STATUS" = "Full" ]; then
    FOLDER="c"
    CLASS="charging-${LEVEL}"
else
    FOLDER="n"
    CLASS="normal-${LEVEL}"
fi

echo "{\"text\": \"$CAPACITY%\", \"class\": \"$CLASS\", \"tooltip\": \"$STATUS ${CAPACITY}%\"}"
