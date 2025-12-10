#!/bin/bash

# Script per avviare il server Python con l'ambiente virtuale
cd "$(dirname "$0")"

# Controlla se l'ambiente virtuale esiste
if [ ! -d "venv" ]; then
    echo "Creazione ambiente virtuale..."
    python3 -m venv venv
fi

# Attiva l'ambiente virtuale
source venv/bin/activate

# Installa/aggiorna le dipendenze se necessario
if [ -f "requirements.txt" ]; then
    echo "Installazione dipendenze..."
    pip install -r requirements.txt
fi

# Avvia il server
echo "Avvio server Flask su http://localhost:8000"
python3 main.py