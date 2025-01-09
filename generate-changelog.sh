#!/bin/bash

# Funzione per incrementare la versione basata sul tag
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
    
    echo "$MAJOR.$MINOR.$PATCH"
}

# Verifica se il file di configurazione esiste
if [ -f config.env ]; then
    source config.env
else
    echo "Errore: Il file config.env non esiste!"
    exit 1
fi

# Controlla se la variabile JIRA_URL è definita
if [ -z "$JIRA_URL" ]; then
    echo "Errore: La variabile JIRA_URL non è definita in config.env!"
    exit 1
fi

# Ottieni l'ultimo tag di Git o usa "0.0.0" se non ci sono tag
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")

# Parametro da linea di comando per specificare la versione da incrementare
if [ "$1" == "--major" ]; then
    NEW_VERSION=$(increment_version "$LAST_TAG" "major")
elif [ "$1" == "--minor" ]; then
    NEW_VERSION=$(increment_version "$LAST_TAG" "minor")
else
    NEW_VERSION=$(increment_version "$LAST_TAG" "patch")
fi

# Data di rilascio in formato "18 Agosto 2023 18:34"
DATE=$(date +"%d %B %Y %H:%M")

# Crea l'intestazione del changelog
echo "# Changelog del $DATE (versione $NEW_VERSION)" > "$CHANGELOG_FILE"
echo "" >> "$CHANGELOG_FILE"

# Scarica i nuovi commit dal repository remoto
git pull origin "$BRANCH"

# Cerca l'ultimo commit con il numero di versione tra parentesi quadre
LAST_VERSION_COMMIT=$(git log --grep="^\[${LAST_TAG}\]" --format="%H" -n 1)

if [ -z "$LAST_VERSION_COMMIT" ]; then
    echo "Nessun commit trovato per il tag ${LAST_TAG}."
    exit 1
fi

# Ottieni la data dell'ultimo commit con il numero di versione
LAST_COMMIT_DATE=$(git log --format="%cI" -n 1 "$LAST_VERSION_COMMIT")

# Se non c'è nessun commit precedente, usa la data dell'ultimo tag
if [ -z "$LAST_COMMIT_DATE" ]; then
    LAST_COMMIT_DATE=$(git show -s --format=%cI "$LAST_TAG")
fi

# Ciclo per generare le sezioni del changelog basato sui gruppi di commit definiti nel file config.env
for VAR in $(compgen -v | grep '^COMMIT_GROUPS_'); do
    TYPE=${VAR#COMMIT_GROUPS_}   # Rimuove il prefisso "COMMIT_GROUPS_"
    EMOJI=${!VAR}                # Ottiene il valore della variabile (emoji o nome)

    # Ottieni i commit successivi alla data dell'ultimo commit con il numero di versione
    COMMITS=$(git log $BRANCH --grep="^\[${TYPE^^}\\]" --pretty=format:"%s (%h)" --reverse --after="$LAST_COMMIT_DATE")

    # Verifica se ci sono commit per quel gruppo
    if [ ! -z "$COMMITS" ]; then
        echo "## ${EMOJI}" >> "$CHANGELOG_FILE"   # Aggiunge la sezione del gruppo
        while IFS= read -r line; do
        echo "DEBUG: Processing commit: $line"
            # Rimuove solo il tag del gruppo (es. [FEAT])
            CLEAN_COMMIT=$(echo "$line" | sed -E 's|^\[[A-Z]+\] ||')
            # Cerca il tag Jira e crea il link
            if [[ "$line" =~ \[([A-Z]+-[0-9]+)\] ]]; then
                JIRA_TAG="${BASH_REMATCH[1]}"
                LINK="[$JIRA_TAG](${JIRA_URL}${JIRA_TAG})"
                
                # Sostituisci solo il codice della issue con il link, ma non mostrare il link completo
                # CLEAN_COMMIT=$(echo "$CLEAN_COMMIT" | sed -E "s|\[$JIRA_TAG\]|$JIRA_TAG|")
                
                # Aggiungi il link solo dietro le quinte (nel commit, ma non visibile nel changelog)
                CLEAN_COMMIT=$(echo "$CLEAN_COMMIT" | sed "s/$JIRA_TAG/$LINK/")
            fi

            # Scrivi il commit nel changelog
            echo "$CLEAN_COMMIT" >> "$CHANGELOG_FILE"
        done <<< "$COMMITS"

        # Aggiunge una riga vuota per separare gruppi
        echo "" >> "$CHANGELOG_FILE"
    fi
done


# Aggiungi il changelog e aggiorna il repository con il nuovo tag
git add "$CHANGELOG_FILE"
git commit -m "[${NEW_VERSION}] - Aggiornamento changelog per la nuova versione"
git tag -a "$NEW_VERSION" -m "Versione $NEW_VERSION"
git push origin "$BRANCH"
git push origin "$NEW_VERSION"
