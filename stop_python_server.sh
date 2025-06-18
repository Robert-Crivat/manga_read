#!/bin/bash

# Script per fermare il server Python
echo "Arresto del server Python..."

if [ -f python_server.pid ]; then
    PID=$(cat python_server.pid)
    if kill -0 $PID 2>/dev/null; then
        kill $PID
        echo "Server Python con PID $PID terminato"
        rm python_server.pid
    else
        echo "Il processo con PID $PID non è in esecuzione"
        rm python_server.pid
    fi
else
    echo "File PID non trovato. Tentativo di terminare tutti i processi sulla porta 5000..."
    lsof -ti:5000 | xargs kill -9 2>/dev/null || true
    echo "Processi terminati"
fi
