#!/bin/bash

# Script per attivare l'ambiente virtuale Python
cd "$(dirname "$0")"

echo "Attivazione ambiente virtuale Python..."
source venv/bin/activate

# Mantieni il terminale aperto nell'ambiente virtuale
exec $SHELL