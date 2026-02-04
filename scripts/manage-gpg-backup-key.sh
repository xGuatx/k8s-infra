#!/bin/bash
# Gestion des cles GPG pour backups securises
# Generation, export, import, et verification

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GPG_EMAIL="${GPG_BACKUP_KEY:-backup@example.com}"

echo ""
echo "        GESTION CLE GPG BACKUP SECURISE                 "
echo ""
echo ""
echo "Email cle GPG: $GPG_EMAIL"
echo ""
echo "Actions disponibles:"
echo "  1. Generer nouvelle cle GPG"
echo "  2. Exporter cle privee (pour sauvegarde)"
echo "  3. Importer cle privee (pour restauration)"
echo "  4. Verifier cle existante"
echo "  5. Tester chiffrement/dechiffrement"
echo "  6. Quitter"
echo ""
read -p "Choix (1-6): " choice

case $choice in
    1)
        echo ""
        echo " GENERATION NOUVELLE CLE GPG "
        echo ""

        # Verifier si cle existe deja
        if gpg --list-keys "$GPG_EMAIL" &>/dev/null; then
            echo "  Cle GPG existante detectee pour $GPG_EMAIL"
            read -p "Supprimer et regenerer? (yes/no): " confirm
            if [ "$confirm" != "yes" ]; then
                echo "Annule."
                exit 0
            fi

            # Supprimer cle existante
            echo "Suppression cle existante..."
            KEY_ID=$(gpg --list-keys "$GPG_EMAIL" | grep -A1 "^pub" | tail -1 | tr -d ' ')
            gpg --batch --yes --delete-secret-keys "$KEY_ID" 2>/dev/null || true
            gpg --batch --yes --delete-keys "$KEY_ID" 2>/dev/null || true
        fi

        echo "Generation cle GPG 4096 bits..."
        echo ""
        read -p "Entrer passphrase (forte, 16+ caracteres) ou vide pour auto: " -s user_passphrase
        echo ""

        if [ -z "$user_passphrase" ]; then
            GPG_PASSPHRASE=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
            echo "Passphrase generee automatiquement"
        else
            GPG_PASSPHRASE="$user_passphrase"
        fi

        # Generer cle
        cat > /tmp/gpg-gen-key.conf <<EOF
%echo Generating GPG key for K8s backups
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: K8s Backup
Name-Email: $GPG_EMAIL
Expire-Date: 0
Passphrase: $GPG_PASSPHRASE
%commit
%echo Done
EOF

        gpg --batch --gen-key /tmp/gpg-gen-key.conf
        rm -f /tmp/gpg-gen-key.conf

        echo ""
        echo " Cle GPG generee avec succes"
        echo ""
        echo "Passphrase: $GPG_PASSPHRASE"
        echo ""
        echo "  IMPORTANT:"
        echo "  1. Sauvegarder cette passphrase dans Password Manager"
        echo "  2. Exporter la cle privee (option 2)"
        echo "  3. Sauvegarder la cle privee dans Password Manager"
        echo ""

        # Sauvegarder dans CREDENTIALS.txt
        if [ -f "$SCRIPT_DIR/../CREDENTIALS.txt" ]; then
            if ! grep -q "GPG BACKUP KEY" "$SCRIPT_DIR/../CREDENTIALS.txt"; then
                cat >> "$SCRIPT_DIR/../CREDENTIALS.txt" <<EOF

GPG BACKUP KEY:
Email: $GPG_EMAIL
Passphrase: $GPG_PASSPHRASE
EOF
                echo " Passphrase ajoutee a CREDENTIALS.txt"
            fi
        fi
        ;;

    2)
        echo ""
        echo " EXPORT CLE PRIVEE GPG "
        echo ""

        if ! gpg --list-keys "$GPG_EMAIL" &>/dev/null; then
            echo " Cle GPG $GPG_EMAIL introuvable!"
            echo "   Generer d'abord avec option 1"
            exit 1
        fi

        OUTPUT_FILE="$SCRIPT_DIR/../backup-gpg-private.key"

        echo "Export cle privee GPG..."
        gpg --export-secret-keys --armor "$GPG_EMAIL" > "$OUTPUT_FILE"
        chmod 600 "$OUTPUT_FILE"

        echo ""
        echo " Cle privee exportee: $OUTPUT_FILE"
        echo ""
        echo "Taille: $(du -h "$OUTPUT_FILE" | cut -f1)"
        echo ""
        echo "  IMPORTANT:"
        echo "  1. Copier ce fichier dans Password Manager"
        echo "  2. Copier sur USB chiffre (coffre-fort physique)"
        echo "  3. NE PAS commiter dans git"
        echo "  4. Supprimer apres sauvegarde:"
        echo "     rm $OUTPUT_FILE"
        echo ""
        ;;

    3)
        echo ""
        echo " IMPORT CLE PRIVEE GPG "
        echo ""

        read -p "Chemin vers cle privee (.key): " key_file

        if [ ! -f "$key_file" ]; then
            echo " Fichier introuvable: $key_file"
            exit 1
        fi

        echo "Import cle privee..."
        gpg --import "$key_file"

        echo ""
        echo "Configuration confiance ultime..."
        echo "trust" > /tmp/gpg-trust-cmd
        echo "5" >> /tmp/gpg-trust-cmd
        echo "y" >> /tmp/gpg-trust-cmd
        echo "quit" >> /tmp/gpg-trust-cmd

        gpg --command-file /tmp/gpg-trust-cmd --edit-key "$GPG_EMAIL" 2>/dev/null || true
        rm -f /tmp/gpg-trust-cmd

        echo ""
        echo " Cle privee importee et configuree"
        echo ""
        echo "Verification:"
        gpg --list-secret-keys "$GPG_EMAIL"
        echo ""
        ;;

    4)
        echo ""
        echo " VERIFICATION CLE GPG "
        echo ""

        if gpg --list-keys "$GPG_EMAIL" &>/dev/null; then
            echo " Cle publique trouvee"
            echo ""
            gpg --list-keys "$GPG_EMAIL"
            echo ""

            if gpg --list-secret-keys "$GPG_EMAIL" &>/dev/null; then
                echo " Cle privee trouvee (peut dechiffrer)"
                echo ""
                gpg --list-secret-keys "$GPG_EMAIL"
            else
                echo "  Cle privee ABSENTE (ne peut pas dechiffrer)"
                echo "   Importer avec option 3"
            fi
        else
            echo " Aucune cle GPG trouvee pour $GPG_EMAIL"
            echo "   Generer avec option 1"
        fi

        echo ""
        echo "Toutes les cles GPG:"
        gpg --list-keys
        echo ""
        ;;

    5)
        echo ""
        echo " TEST CHIFFREMENT/DECHIFFREMENT "
        echo ""

        if ! gpg --list-keys "$GPG_EMAIL" &>/dev/null; then
            echo " Cle GPG $GPG_EMAIL introuvable!"
            exit 1
        fi

        # Creer fichier test
        TEST_FILE="/tmp/gpg-test-$$"
        echo "Test backup securise K8s - $(date)" > "$TEST_FILE"
        echo "Donnees sensibles simulees" >> "$TEST_FILE"

        echo "Fichier test cree: $TEST_FILE"
        echo "Contenu original:"
        cat "$TEST_FILE"
        echo ""

        # Chiffrer
        echo "Chiffrement avec GPG..."
        gpg --encrypt --recipient "$GPG_EMAIL" --batch --yes --quiet "$TEST_FILE"

        if [ -f "$TEST_FILE.gpg" ]; then
            echo " Fichier chiffre: $TEST_FILE.gpg"
            echo "  Taille: $(du -h "$TEST_FILE.gpg" | cut -f1)"
        else
            echo " Echec chiffrement"
            exit 1
        fi

        # Verifier que cle privee existe pour dechiffrer
        if ! gpg --list-secret-keys "$GPG_EMAIL" &>/dev/null; then
            echo ""
            echo "  Cle privee absente - impossible de tester dechiffrement"
            echo "   Chiffrement OK, mais pour tester dechiffrement:"
            echo "   Importer cle privee avec option 3"
            rm -f "$TEST_FILE" "$TEST_FILE.gpg"
            exit 0
        fi

        # Dechiffrer
        echo ""
        echo "Dechiffrement avec GPG..."
        gpg --decrypt --batch --yes --quiet "$TEST_FILE.gpg" > "$TEST_FILE.decrypted" 2>/dev/null

        if [ -f "$TEST_FILE.decrypted" ]; then
            echo " Fichier dechiffre: $TEST_FILE.decrypted"
            echo ""
            echo "Contenu dechiffre:"
            cat "$TEST_FILE.decrypted"
            echo ""

            # Comparer
            if diff "$TEST_FILE" "$TEST_FILE.decrypted" &>/dev/null; then
                echo " TEST REUSSI - Chiffrement/Dechiffrement fonctionnel"
            else
                echo " ERREUR - Contenu different apres dechiffrement"
            fi
        else
            echo " Echec dechiffrement"
        fi

        # Nettoyage
        rm -f "$TEST_FILE" "$TEST_FILE.gpg" "$TEST_FILE.decrypted"
        echo ""
        ;;

    6)
        echo "Quitter."
        exit 0
        ;;

    *)
        echo " Choix invalide"
        exit 1
        ;;
esac

echo ""
echo ""
echo "Pour utiliser avec backups securises:"
echo "  export GPG_BACKUP_KEY=\"$GPG_EMAIL\""
echo "  $SCRIPT_DIR/../backup/backup-to-k8s-orchestrator-secure.sh"
echo ""
echo "Pour restaurer:"
echo "  $SCRIPT_DIR/../backup/restore-from-secure-backup.sh"
echo ""
echo ""
