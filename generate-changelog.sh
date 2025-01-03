#!/bin/bash

# Funzione per incrementare la versione
increment_version() {
    local version=$1
    local part=$2
    IFS='.' read -r MAJOR MINOR PATCH <<< "$version"
    
    case "$part" in
        "major")
            MAJOR=$((MAJOR + 1))
            MINOR=0
            PATCH=0
            ;;
        "minor")
            MINOR=$((MINOR + 1))
            PATCH=0
            ;;
        "patch")
            PATCH=$((PATCH + 1))
            ;;
        *)
            echo "Errore: Parametro di versione non valido. Usa major, minor o patch."
            exit 1
            ;;
    esac
    
    # Restituisce la nuova versione
    echo "$MAJOR.$MINOR.$PATCH"
}

# Verifica se il file di configurazione esiste
if [ -f config.env ]; then
    source config.env
else
    echo "Errore: Il file config.env non esiste!"
    exit 1
fi

# Verifica se il file VERSION esiste
if [ ! -f "$VERSION_FILE" ]; then
    echo "0.0.1" > "$VERSION_FILE" # Inizializza la versione se non esiste
fi

# Leggi la versione attuale dal file
CURRENT_VERSION=$(cat "$VERSION_FILE")

# Parametro da linea di comando per specificare la versione da incrementare
if [ "$1" == "--major" ]; then
    NEW_VERSION=$(increment_version "$CURRENT_VERSION" "major")
elif [ "$1" == "--minor" ]; then
    NEW_VERSION=$(increment_version "$CURRENT_VERSION" "minor")
else
    NEW_VERSION=$(increment_version "$CURRENT_VERSION" "patch")
fi

# Aggiorna il file VERSION con la nuova versione
echo "$NEW_VERSION" > "$VERSION_FILE"

# Data di rilascio
DATE=$(date +"%Y-%m-%d")

# Crea l'intestazione del changelog
echo "# [${NEW_VERSION}] - Changelog ${DATE}" > "$CHANGELOG_FILE"
echo "" >> "$CHANGELOG_FILE"

# Scarica i nuovi commit dal repository remoto
git pull origin "$BRANCH"

# Ottieni l'ultimo commit presente nel changelog, se esiste
LAST_COMMIT_HASH=$(git log --grep="^\\[CHANGELOG\\]" --format="%h" -n 1 ) 

# Ciclo per generare le sezioni del changelog basato sui gruppi di commit definiti nel file config.env
for VAR in $(compgen -v | grep '^COMMIT_GROUPS_'); do
    TYPE=${VAR#COMMIT_GROUPS_}   # Rimuove il prefisso "COMMIT_GROUPS_"
    EMOJI=${!VAR}                # Ottiene il valore della variabile (emoji o nome)
    
    # Se non c'è un commit precedente, considera tutto il log; altrimenti, considera solo i commit dopo l'ultimo changelog
    if [ -z "$LAST_COMMIT_HASH" ]; then
        COMMITS=$(git log $BRANCH --grep="^\\[${TYPE^^}\\]" --pretty=format:"- %s (%h)" --since="1 week ago")
    else
        COMMITS=$(git log $BRANCH --grep="^\\[${TYPE^^}\\]" --pretty=format:"- %s (%h)" --since="1 week ago" --after="$LAST_COMMIT_HASH")
    fi
    
    if [ ! -z "$COMMITS" ]; then
        echo "## ${EMOJI}" >> "$CHANGELOG_FILE"   # Aggiunge la sezione del gruppo
        echo "$COMMITS" >> "$CHANGELOG_FILE"      # Aggiunge i commit al changelog
        echo "" >> "$CHANGELOG_FILE"              # Aggiunge una riga vuota per separare
    fi
done

# Aggiungi il changelog e aggiorna il repository
git add "$CHANGELOG_FILE" "$VERSION_FILE"
git commit -m "[CHANGELOG] Aggiornamento changelog per la versione ${NEW_VERSION}"
git push origin "$BRANCH"
