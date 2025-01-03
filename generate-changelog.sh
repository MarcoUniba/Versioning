#!/bin/bash

# Carica il file di configurazione
if [ -f config.env ]; then
    source config.env
else
    echo "Errore: Il file config.env non esiste!"
    exit 1
fi

# Verifica che la versione sia definita
if [ -z "$VERSION" ]; then
    echo "Errore: La variabile VERSION non è definita in config.env!"
    exit 1
fi

# Data di rilascio
DATE=$(date +"%Y-%m-%d")

# Intestazione del changelog
echo "# [${VERSION}] - Changelog ${DATE}" > "$CHANGELOG_FILE"
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
git add "$CHANGELOG_FILE"
git commit -m "chore: update changelog for version ${VERSION}"
git push origin "$BRANCH"
