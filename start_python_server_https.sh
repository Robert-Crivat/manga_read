#!/bin/bash

# Script per avviare il server Python in HTTPS
echo "Avvio del server Python in modalità HTTPS..."

# Controlla se OpenSSL è installato
if ! command -v openssl &> /dev/null; then
    echo "ERRORE: OpenSSL non trovato. Installalo con: brew install openssl"
    exit 1
fi

cd "$(dirname "$0")"

# Crea certificati auto-firmati se non esistono
if [ ! -f "server.crt" ] || [ ! -f "server.key" ]; then
    echo "Creazione certificati auto-firmati..."
    openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -days 365 -nodes -subj '/C=IT/ST=Italy/L=Rome/O=MangaReader/CN=localhost'
    echo "Certificati creati: server.crt e server.key"
fi

# Chiama lo script principale con parametro HTTPS
./start_python_server.sh https