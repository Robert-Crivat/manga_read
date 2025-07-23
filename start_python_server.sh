#!/bin/bash

# Script per avviare il server Python in background
echo "Avvio del server Python..."

# Uccidi eventuali processi esistenti sulla porta 8000
echo "Chiusura processi esistenti sulla porta 8000..."
lsof -ti:8000 | xargs kill -9 2>/dev/null || true

# Avvia il server Python in background
echo "Avvio server Flask..."
cd "$(dirname "$0")"
./.venv/bin/python main.py &

# Salva il PID del processo
echo $! > python_server.pid
echo "Server Python avviato con PID: $!"
echo "Il server è disponibile su http://localhost:8000"

# Aspetta un momento per verificare che il server sia partito
sleep 2

# Verifica se il server è in esecuzione
if curl -s http://localhost:8000/search_manga?keyword=test > /dev/null; then
    echo "✅ Server Python è attivo e funzionante!"
else
    echo "❌ Errore: Il server Python non risponde"
fi
