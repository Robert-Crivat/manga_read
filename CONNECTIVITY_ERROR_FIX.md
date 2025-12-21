# Gestione degli errori del plugin connectivity_plus

## Problema
Il plugin `connectivity_plus` può causare un `MissingPluginException` su simulatori iOS o quando il plugin non è correttamente configurato.

## Soluzione implementata
1. **Try-catch intorno a tutti i controlli di connettività**: Ogni chiamata a `Connectivity().checkConnectivity()` è racchiusa in un try-catch.

2. **Fallback intelligente**: Se il plugin non è disponibile, l'app assume che la connessione sia disponibile per default.

3. **Debug dettagliato**: Aggiunto logging per tracciare i problemi del plugin.

## Comportamento per modalità:
- **Online mode**: Se il plugin funziona, controlla la connessione reale. Se il plugin non funziona, assume connessione disponibile.
- **Offline mode**: Ignora completamente il controllo di connettività e usa sempre i file locali.
- **Auto-detection**: Usa parametri `offlineMangaName` per determinare se usare modalità offline anche senza `isOfflineMode`.

## Controlli di sicurezza implementati:
```dart
// Condizione unificata per modalità offline
if (widget.isOfflineMode || !isConnected || widget.offlineMangaName != null) {
    // Usa modalità offline
}
```

Questo garantisce che l'app funzioni sempre, indipendentemente dallo stato del plugin connectivity_plus.

## Test
Per testare il comportamento:
1. Esegui l'app su simulatore iOS (dove il plugin spesso fallisce)
2. Controlla i log di debug per vedere se il plugin è disponibile
3. Verifica che l'app funzioni correttamente in entrambi i casi

## Note per sviluppatori
- Il plugin `connectivity_plus` non è sempre disponibile sui simulatori
- L'app deve essere progettata per funzionare senza dipendere completamente dal plugin
- L'assunzione di connessione disponibile come fallback è ragionevole per la maggior parte dei casi d'uso