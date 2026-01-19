#!/bin/bash

# Script d'installation automatique MariaDB avec Docker pour DEBIAN
# Usage: sudo bash install.sh

set -e  # Arrête le script en cas d'erreur

echo "=========================================="
echo "Installation de Docker et MariaDB"
echo "=========================================="
echo ""

# Vérifier si le script est lancé en root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Erreur: Ce script doit être lancé avec sudo"
    echo "Usage: sudo bash install.sh"
    exit 1
fi

# Vérifier si dump.sql existe
if [ ! -f "dump.sql" ]; then
    echo "❌ Erreur: Le fichier dump.sql est introuvable !"
    echo "Assurez-vous que dump.sql est dans le même dossier que ce script."
    exit 1
fi

echo "✓ Fichier dump.sql trouvé"
echo ""

# 1. Installation de Docker
echo "📦 Installation de Docker..."
if command -v docker &> /dev/null; then
    echo "✓ Docker est déjà installé"
else
    # Mise à jour des paquets
    apt-get update -y
    
    # Installation des dépendances
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Ajout de la clé GPG officielle de Docker POUR DEBIAN
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Ajout du dépôt Docker POUR DEBIAN
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Installation de Docker
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Démarrage de Docker
    systemctl start docker
    systemctl enable docker
    
    echo "✓ Docker installé avec succès"
fi
echo ""

# 2. Installation de Docker Compose
echo "📦 Installation de Docker Compose..."
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null 2>&1; then
    echo "✓ Docker Compose est déjà installé"
else
    apt-get install -y docker-compose-plugin
    echo "✓ Docker Compose installé avec succès"
fi
echo ""

# 3. Vérification des versions
echo "📋 Versions installées:"
docker --version
docker compose version 2>/dev/null || docker-compose --version
echo ""

# 4. Lancement de MariaDB avec Docker Compose
echo "🚀 Lancement de MariaDB..."

# Vérifier si un conteneur mariadb existe déjà
if [ "$(docker ps -aq -f name=mariadb)" ]; then
    echo "⚠️  Un conteneur mariadb existe déjà"
    read -p "Voulez-vous le supprimer et recommencer ? (o/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        echo "🗑️  Suppression de l'ancien conteneur..."
        docker compose down -v 2>/dev/null || docker-compose down -v
        echo "✓ Ancien conteneur supprimé"
    else
        echo "ℹ️  Conservation du conteneur existant"
        exit 0
    fi
fi

# Lancement de Docker Compose (essaye les deux syntaxes)
docker compose up -d 2>/dev/null || docker-compose up -d

echo ""
echo "⏳ Attente du démarrage de MariaDB (30 secondes)..."
sleep 30

# Vérification du statut
if [ "$(docker ps -q -f name=mariadb)" ]; then
    
    # Création d'un alias pour faciliter la connexion
    echo ""
    echo "🔧 Création d'un alias 'mysql' pour faciliter la connexion..."
    
    # Ajouter l'alias dans .bashrc si pas déjà présent
    if ! grep -q "alias mysql=" ~/.bashrc 2>/dev/null; then
        echo "alias mysql='sudo docker exec -it mariadb mariadb -u root -psalut'" >> ~/.bashrc
        echo "✓ Alias ajouté dans ~/.bashrc"
    fi
    
    # Ajouter aussi pour l'utilisateur qui a lancé sudo
    if [ -n "$SUDO_USER" ]; then
        SUDO_HOME=$(eval echo ~$SUDO_USER)
        if ! grep -q "alias mysql=" "$SUDO_HOME/.bashrc" 2>/dev/null; then
            echo "alias mysql='sudo docker exec -it mariadb mariadb -u root -psalut'" >> "$SUDO_HOME/.bashrc"
            chown $SUDO_USER:$SUDO_USER "$SUDO_HOME/.bashrc"
            echo "✓ Alias ajouté pour l'utilisateur $SUDO_USER"
        fi
    fi
    
    echo ""
    echo "=========================================="
    echo "✅ Installation terminée avec succès !"
    echo "=========================================="
    echo ""
    echo "📊 Statut du conteneur:"
    docker ps -f name=mariadb
    echo ""
    echo "🔗 Informations de connexion:"
    echo "  IP serveur: $(hostname -I | awk '{print $1}')"
    echo "  Port: 3306"
    echo "  Base: centres_commerciaux"
    echo "  User: root"
    echo "  Password: salut"
    echo ""
    echo "🔧 Commandes utiles:"
    echo "  - Se connecter:         mysql (raccourci créé !)"
    echo "  - Ou:                   sudo docker exec -it mariadb mariadb -u root -psalut"
    echo "  - Voir les logs:        docker compose logs -f mariadb"
    echo "  - Arrêter:              docker compose down"
    echo "  - Redémarrer:           docker compose restart"
    echo "  - Supprimer tout:       docker compose down -v"
    echo ""
    echo "🔒 Mot de passe root: salut"
    echo "   ⚠️  N'oubliez pas de le changer !"
    echo ""
    echo "💡 Pour utiliser l'alias 'mysql', tapez:"
    echo "   source ~/.bashrc"
    echo "   Puis simplement: mysql"
    echo ""
else
    echo ""
    echo "❌ Erreur: Le conteneur n'a pas démarré correctement"
    echo "Consultez les logs avec: docker compose logs mariadb"
    exit 1
fi
