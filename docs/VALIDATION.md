## Version 0.2.0 — assistant et visuels

- Analyse Dart et 29 tests automatisés réussis sur Mac : migration des données, conflits et marges, objectifs hebdomadaires, soirées/week-ends, propositions périmées, persistance des images, import simulé et refus de permission, personnalisation, couleurs et navigation mobile/bureau.
- Rendu relu sur captures téléphone 390 px et bureau ; filtres avancés repliables, priorités repliables, suggestions sur deux colonnes sur grand écran.
- Caméra iPhone : code et permissions ajoutés ; validation physique en attente du téléphone connecté et de la signature Apple. L’import simulé n’est pas un test matériel de caméra.
- Données locales uniquement, objectifs à configurer dans Assistant → réglages, pas de synchronisation Mac/iPhone ou d’analyse du contenu des photos.

Parcours à vérifier sur l’iPhone : nouvelle tâche → Photo → autoriser → prendre une photo → enregistrer → fermer/rouvrir → zoom ; répéter avec refus d’autorisation. Pour le planning : créer un objectif Musique, 20 min, trois fois/semaine le soir, ajouter une suggestion puis vérifier sa présence dans Agenda et le compteur hebdomadaire.

# Parcours de validation de la V1

## Avant d'utiliser des données réelles

- Lancer en mode découverte. Les données de l'exemple sont fictives.
- Ouvrir Paramètres et définir prénom, jours travaillés, horaires et pause.
- Après exploration, copier la sauvegarde si nécessaire puis repartir avec un espace vide.

## Sur iPhone

1. Créer « Préparer mon support », durée 90 min, échéance demain 18h.
2. Ouvrir la tâche, ajouter trois sous-tâches et en cocher une : vérifier 33 %.
3. Choisir « Trouver un créneau », sélectionner une proposition et la retrouver dans Agenda.
4. Créer une seconde tâche sur le même créneau : vérifier le refus explicite.
5. Démarrer le focus, fermer l'écran, revenir, mettre en pause, puis terminer.
6. Fermer et rouvrir l'app : vérifier la conservation des données et du temps.
7. Tester les filtres, le Board et le déplacement d'une tâche par appui long.
8. Créer un client et une mission, rattacher une tâche puis la terminer : vérifier l'avancement.
9. Ouvrir l'aperçu client et copier les disponibilités : vérifier l'absence des titres et des notes privées.
10. Passer au thème sombre, augmenter la taille de texte iOS, vérifier clavier, SafeArea et retour arrière.

## Limites à valider explicitement

- Sur Mac : lancer `bash tool/install_macos.command`, vérifier l'ouverture depuis Applications et la conservation des données après fermeture.
- Annuler une tâche planifiée, réserver le créneau avec une autre tâche, puis essayer de rouvrir la première : le conflit doit être signalé.
- Modifier le titre d'une tâche annulée : elle doit rester annulée.
- Personnaliser les horaires et le thème, puis effacer les données de découverte : les préférences doivent rester conservées.

- Le chronomètre mesure le temps écoulé, y compris en arrière-plan, tant qu'il n'est pas arrêté.
- Pas de rappel système ni de notification push dans la V1 locale.
- Les blocs agenda sont déplacés sur les heures de la grille. Pour une heure précise, modifier la tâche.
- Un export copié dans le presse-papiers doit être enregistré manuellement dans un fichier.
- Les changements d'horaires ne déplacent pas les réservations existantes.
- Les créneaux utilisent le fuseau courant du téléphone ; la gestion de plusieurs fuseaux sera à définir lors de la synchronisation.
