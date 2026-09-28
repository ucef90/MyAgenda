# Connexion privée MyAgenda ↔ ChatGPT Work (0.5)

La version 0.5 fournit un serveur privé, un connecteur MCP authentifié et un écran **Agenda & connexions → ChatGPT Work** sur iPhone et Mac. Le code doit être déployé sur votre serveur HTTPS avant de pouvoir associer les appareils. Aucune adresse de production n’est fournie dans le dépôt.

## Ce que fait la connexion

1. Vous associez l’appareil avec un code temporaire et choisissez les tâches partagées : formations uniquement par défaut, ou formations et tâches professionnelles.
2. MyAgenda publie leurs titres, projets, catégories, dates, durées, statuts et trois points de préparation. Les notes, contacts clients, photos et audios ne sont jamais envoyés au serveur.
3. Dans Work, le connecteur **MyAgenda** lit cet instantané. Le connecteur **Gmail**, autorisé séparément dans Work, permet de rechercher les mails pertinents.
4. Work propose une confirmation pour le support, le bon de commande signé ou le mail envoyé. Une conclusion oui/non exige au moins une référence Gmail ; une recherche infructueuse reste **À vérifier**.
5. Dans MyAgenda, vous ouvrez la source puis **Confirmer** ou **Refuser**. Seule cette confirmation modifie la tâche locale. Le motif et les références restent visibles dans la formation.

Il s’agit de références proposées par Work : le serveur ne lit pas Gmail et ne certifie pas la véracité du mail ou d’une signature. Il n’existe aucun outil d’envoi de mail dans ce connecteur.

## Déployer le serveur

Prévoir un serveur privé avec Docker Compose, un nom de domaine pointant dessus et les ports 80/443 accessibles. N’exposez pas directement le port 8787. Le serveur est conçu pour **un propriétaire**, pas pour plusieurs comptes indépendants.

Dans `server/` :

```sh
cp .env.example .env
# Renseigner MYAGENDA_DOMAIN dans .env avec le vrai domaine.
docker compose build
```

Dans les paramètres de création du connecteur MCP de Work, récupérez **l’URL de retour OAuth exacte**. Elle peut être propre au connecteur : ne devinez pas son identifiant. Ce serveur n’annonce pas l’extension d’identification de l’émetteur dans la réponse ; utilisez le callback fourni pour cette configuration. Si l’interface impose de créer d’abord le connecteur, configurez un callback HTTPS temporaire sous votre propre domaine, puis remplacez-le par le callback affiché avant d’autoriser Work.

```sh
docker compose run --rm bridge node src/cli.mjs setup \
  --url https://VOTRE_DOMAINE \
  --redirect URL_DE_RETOUR_EXACTE_DE_WORK
```

Le mot de passe propriétaire est généré aléatoirement dans `/app/data/owner-password.txt`, avec des droits restreints. Ouvrez-le **dans votre terminal privé**, conservez-le dans un gestionnaire de mots de passe puis supprimez ce fichier. Ne transmettez ni ce mot de passe ni les codes d’association dans une conversation ou un ticket.

```sh
docker compose run --rm bridge cat /app/data/owner-password.txt
docker compose run --rm bridge rm /app/data/owner-password.txt
docker compose up -d
```

Caddy délivre le certificat HTTPS si le DNS et les ports sont corrects. `https://VOTRE_DOMAINE/health` expose uniquement le nom et la version du service. Sauvegardez le volume `agenda_data` par un mécanisme privé et chiffré ; il contient les instantanés, les autorisations et les références de mails.

Pour changer le callback, puis redémarrer :

```sh
docker compose run --rm bridge node src/cli.mjs callback URL_DE_RETOUR_EXACTE_DE_WORK
docker compose restart bridge
```

Pour un développement local, Node 24 ou ultérieur et `npm ci` suffisent. La commande `npm start` utilise `MYAGENDA_DATA` (par défaut `server/data` si lancée depuis `server/`) et écoute sur `127.0.0.1:8787`. L’application mobile exige une véritable URL HTTPS ; elle refuse les redirections et ne désactive jamais la validation des certificats. Les tests utilisent un serveur HTTP éphémère sur loopback, sans compte réel.

## Associer l’iPhone ou le Mac

```sh
docker compose exec bridge node src/cli.mjs pair
docker compose exec bridge cat /app/data/pairing-code.txt
```

Le code comporte 20 caractères hexadécimaux, expire après 10 minutes et n’est utilisable qu’une fois. Dans **MyAgenda → Agenda & connexions → ChatGPT Work**, saisir l’adresse HTTPS (sans `/mcp`), un nom pour l’appareil et ce code, puis **Relier mon agenda**. Effacez ensuite `pairing-code.txt`.

L’application conserve son jeton dans le **Trousseau Apple de cet appareil**. Aucun jeton n’entre dans les exports de tâches. Chaque appareil possède son propre instantané : les tâches locales d’un Mac et d’un iPhone ne sont pas fusionnées automatiquement.

## Ajouter MyAgenda dans Work

Selon l’interface et les droits du compte, utilisez l’ajout de serveur MCP dans Work ou la création d’un connecteur/plugin en mode développeur. L’adresse est :

```text
https://VOTRE_DOMAINE/mcp
```

Autorisez l’accès sur la page de **votre serveur MyAgenda** avec le mot de passe propriétaire. Les portées sont `agenda:read` et `agenda:propose`. Le protocole utilise OAuth avec PKCE S256, callback exact, audience contrôlée, codes à usage unique et rotation des refresh tokens. L’enregistrement dynamique d’un client ne lui donne aucun accès avant votre autorisation.

Si un fichier de configuration MCP est demandé :

```sh
docker compose exec -T bridge node src/cli.mjs manifest > myagenda-mcp.json
```

Le fichier `myagenda-mcp.json` contient uniquement l’adresse du connecteur, sans identifiant secret. Aucune installation de plugin personnalisé n’est faite automatiquement par MyAgenda.

Activez aussi Gmail dans Work avec le compte que vous souhaitez analyser. La connexion Gmail de Work n’est pas copiée dans MyAgenda ; aucune clé OpenAI ni clé Gmail n’est nécessaire dans ce dépôt.

Exemple de demande :

> Lis les prochaines formations de mon iPhone dans MyAgenda. Vérifie dans Gmail le support prêt, le bon de commande signé et le mail de confirmation envoyé. Recoupe le client, la date et la formation. Propose une mise à jour avec les mails qui la justifient ; laisse À vérifier si tu ne peux pas conclure. N’envoie aucun mail.

Ouvrez MyAgenda, vérifiez la dernière synchronisation, puis **Actualiser maintenant** pour récupérer les propositions. Les recherches Gmail sont déclenchées dans Work ; cette version ne fait pas d’analyse permanente en arrière-plan.

## Cohérence, suppression et limites

- L’application sauvegarde avant de partager ou d’accuser réception d’une confirmation. Une coupure entre sauvegarde et accusé de réception ne réapplique pas la confirmation.
- Les propositions portent sur une version précise de la formation. Un changement de titre, de date, de statut ou du point concerné empêche l’acceptation. Les trois points indépendants peuvent être validés successivement.
- Les instantanés utilisent une révision croissante par appareil. Une ancienne requête ne remplace pas un instantané plus récent.
- La synchronisation se fait à l’ouverture, après les modifications et chaque minute au premier plan. iOS ne garantit pas l’exécution de l’application fermée. Un instantané ancien doit être actualisé avant une analyse.
- Le changement de périmètre prend effet après un échange réussi. Les tâches retirées et leurs propositions sont supprimées du serveur ; les conversations déjà faites dans Work ne sont pas effacées.
- Limites : 1 000 tâches partagées par appareil, 200 propositions en attente, conservation des propositions pendant 30 jours. Les instantanés sont conservés jusqu’à leur remplacement ou la suppression de l’appareil. Les jetons Work expirent après une heure, leur renouvellement après 30 jours.
- **Déconnecter et retirer les données partagées** supprime l’instantané et les propositions de cet appareil ; les tâches locales restent intactes. Une connexion réseau est nécessaire pour confirmer la suppression distante.

Révocation depuis le serveur :

```sh
docker compose exec bridge node src/cli.mjs devices
docker compose exec bridge node src/cli.mjs revoke-device IDENTIFIANT_APPAREIL
docker compose exec bridge node src/cli.mjs revoke-work
```

## Vérifications et sources

`npm test --prefix server` couvre l’association, l’accès HTTP et MCP, le consentement, PKCE, les codes rejoués, l’audience, les portées, les jetons renouvelés, les données privées refusées, les versions anciennes et l’isolation des appareils. Les tests Flutter vérifient la sélection des données, les conflits de préparation, la conservation des sources et la reprise après une coupure.

Documentation officielle consultée :

- https://developers.openai.com/plugins/build/auth
- https://developers.openai.com/plugins/build/mcp-server
- https://developers.openai.com/plugins/deploy/connect-chatgpt
- https://developers.openai.com/plugins/build/plugins
- https://github.com/modelcontextprotocol/typescript-sdk
