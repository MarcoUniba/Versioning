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

# Carica il file di configurazione
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

# Parametri da linea di comando (incrementa la versione specifica)
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

# Intestazione del changelog
echo "# [${NEW_VERSION}] - Changelog ${DATE}" > "$CHANGELOG_FILE"
echo "" >> "$CHANGELOG_FILE"

# Gruppi di commit (dinamici dal file di configurazione)
for VAR in $(compgen -v | grep '^COMMIT_GROUPS_'); do
    TYPE=${VAR#COMMIT_GROUPS_} # Rimuove il prefisso
    EMOJI=${!VAR}             # Ottiene il valore della variabile
    COMMITS=$(git log $BRANCH --grep="^\\[${TYPE^^}\\]" --pretty=format:"- %s (%h)" --since="1 week ago")
    if [ ! -z "$COMMITS" ]; then
        echo "## ${EMOJI}" >> "$CHANGELOG_FILE"
        echo "$COMMITS" >> "$CHANGELOG_FILE"
        echo "" >> "$CHANGELOG_FILE"
    fi
done

# Aggiungi il changelog e aggiorna il repository
git add "$CHANGELOG_FILE" "$VERSION_FILE"
git commit -m "update changelog for version ${NEW_VERSION}"
git push origin "$BRANCH"
