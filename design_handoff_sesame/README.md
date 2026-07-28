# Handoff : Sésame — Coffre-fort de documents local (iOS/Android)

## Aperçu
Sésame est une application mobile de stockage **100 % local** de documents sensibles (passeports, cartes, PDF, notes). Aucune composante cloud : chiffrement sur l'appareil, pas de compte, pas de serveur. Fonctions clés : catégorisation par étiquettes multiples, recherche par nom, partage AirDrop sécurisé (fichier chiffré + mot de passe communiqué à part).

## À propos des fichiers de design
Les fichiers de ce paquet sont des **références de design créées en HTML** — des prototypes montrant l'apparence et le comportement visés, PAS du code de production à copier. La tâche est de **recréer ces écrans dans l'environnement du projet cible** (SwiftUI / Kotlin Compose / React Native / Flutter…) avec ses patterns et bibliothèques. Si aucun environnement n'existe encore, choisir le framework le plus approprié (une app iOS+Android sans cloud suggère React Native, Flutter, ou natif double).

## Fidélité
**Haute fidélité (hifi)** pour la direction retenue « Pop clair » (option 1c + turn 2) : couleurs, typo, espacements et copies sont finaux — recréer fidèlement. Les options 1a « Douceur » et 1b « Nocturne » du fichier sont des directions écartées, conservées pour référence seulement.

## Direction retenue : « Pop clair »
Blanc net, accent indigo, étiquettes de catégories colorées, ton simple et convivial. Langue de la maquette : français (l'app sera multilingue).

## Écrans / Vues (direction 1c + turn 2)

### 1. Déverrouillage
- **But** : entrer dans le coffre via Face ID, PIN ou mot de passe.
- **Layout** : colonne centrée verticalement, padding 32px.
- **Composants** : logo (cercle 76px indigo #5b5bd6, carré arrondi blanc 30px centré), titre « Sésame » 30px/800 #17171f letter-spacing -0.03em, sous-titre 15px #71717d « Simple. Privé. Tout reste ici, sur votre téléphone. », 3 chips d'exemple (Passeports/Ordonnances/Contrats), bouton principal pleine largeur « Déverrouiller avec Face ID » (fond #5b5bd6, blanc 16px/700, radius 16px, ombre 0 10px 24px rgba(91,91,214,.25)), lien « Code PIN ou mot de passe » 15px/600 #5b5bd6, note bas de page 12px #a5a5b0 « Verrouillage automatique après 60 s d'inactivité ».

### 2. Accueil / Coffre
- **But** : vue d'ensemble, filtrage par catégorie, accès rapide.
- **Layout** : colonne, padding 64px 20px 0 (le padding-top 64px réserve la barre d'état/île dynamique).
- **Composants** : titre « Coffre » 30px/800 ; 2 boutons ronds 38px (#f0f0f4) recherche + réglages ; rangée de chips-filtres (actif : fond #5b5bd6 texte blanc ; inactifs : pastille colorée par catégorie, voir tokens ; chip « + » en pointillé pour créer une catégorie) ; grille 2 colonnes (gap 12px) de cartes document : fond #fff, bordure 1px #ececf1, radius 18px, vignette 110px (placeholder), badge type (PDF/NOTE), titre 14px/700, chips d'étiquettes 10.5px/600 ; bouton flottant centré bas « + Ajouter » (pilule noire #17171f, blanc 15px/700, ombre).
- **Note** : un document peut porter **plusieurs étiquettes** (modèle tags, pas dossiers).

### 3. Détail document
- **But** : consulter, étiqueter, partager.
- **Layout** : colonne, padding 64px 20px 0 ; nav « ‹ Coffre » / « Modifier » en #5b5bd6 600.
- **Composants** : aperçu 240px radius 20px ; titre 24px/800 ; chips étiquettes + « + étiquette » pointillé ; carte méta (fond #fff, radius 18px) lignes « Ajouté le / Expire le / Taille » 14.5px, valeur d'expiration en #c15c9a 700 (alerte) ; 2 boutons bas : primaire « Partager par AirDrop sécurisé » (#5b5bd6) et secondaire « Exporter chiffré (.zip + mot de passe) » (blanc, bordure #ececf1).

### 4. Ajouter un document
- **But** : 5 méthodes d'ajout.
- **Composants** : liste de cartes radius 18px, padding 20px, icône 44px teintée : Scanner (carte primaire indigo pleine, « Recadrage automatique des bords »), Prendre une photo, Importer de la galerie, Importer un fichier (PDF), Nouvelle note. Pied : « Tout est chiffré dès l'ajout · rien ne quitte l'appareil » 12px #a5a5b0.

### 5. Onboarding (1/3)
- Pastilles de progression (active : 22×6px #5b5bd6), titre 34px/800 « Vos documents, seulement ici. », paragraphe 16px #71717d, 3 lignes bénéfices avec icônes 36px teintées, CTA « Commencer », note « Étape suivante : choisir Face ID ou un code PIN ».

### 6. Recherche
- **Layout** : champ de recherche en tête (fond #f0f0f4, radius 14px) + « Annuler », clavier iOS visible.
- **Comportement** : recherche **par nom de document**, temps réel ; segments Tout/Images/PDF/Notes ; compteur « 2 résultats » ; le terme trouvé est surligné (fond #ececfa, texte #5b5bd6) dans le titre du résultat.

### 7. Partage AirDrop sécurisé (feuille modale)
- **Layout** : bottom sheet radius 28px haut sur fond assombri rgba(23,23,31,.4), poignée 36×5px.
- **Comportement** : 2 modes radio — « Chiffré avec mot de passe » (défaut, bordure 2px #5b5bd6, coche) et « Envoi AirDrop simple » ; encadré mot de passe généré (fond #ececfa, mono 17px, ex. « corail-lampe-92-nuit », action Copier) ; CTA « Continuer vers AirDrop ». Le mot de passe doit être communiqué **par un autre canal**.

### 8. Réglages
- Groupes iOS (cartes blanches radius 18px, libellés de section 12.5px uppercase #a5a5b0) :
  - **Sécurité** : Face ID (toggle actif #5b5bd6), Code PIN › Modifier, Verrouillage auto › 60 secondes.
  - **Données** : Gérer les catégories (6), Sauvegarde chiffrée locale (« Export manuel vers Fichiers, jamais automatique »), Langue.
  - Action destructive centrée « Effacer tout le coffre… » en #c15c9a.
- Pied : « Sésame 1.0 · aucune donnée collectée ».

## Interactions & comportement
- Verrouillage auto après 60 s d'inactivité (retour à l'écran de déverrouillage) ; retour au premier plan = re-authentification.
- Face ID → fallback PIN → fallback mot de passe.
- Recherche en temps réel sur le nom, surlignage du terme.
- Un document ⇄ plusieurs étiquettes ; création de catégorie via chip « + ».
- Partage : générer un mot de passe type « mot-mot-nombre-mot », archiver le fichier chiffré (ex. AES-256), puis ouvrir la share sheet native (AirDrop / Nearby Share sur Android).
- Alerte visuelle (couleur #c15c9a) quand une date d'expiration approche.
- Transitions : standard plateforme (push nav, sheet modale) ; pas d'animations exotiques.

## Gestion d'état
- `isLocked`, `authMethod` (faceid|pin|password), `lastActiveAt` (pour l'auto-lock).
- `documents[]` : {id, nom, type (image|pdf|note), tailleOctets, ajoutéLe, expireLe?, tagIds[], fichierChiffré}.
- `categories[]` : {id, nom, couleur}.
- `searchQuery`, `typeFilter`, `activeCategoryId`.
- Aucune requête réseau. Stockage : fichiers chiffrés + base locale (Keychain/Keystore pour les clés).

## Design tokens
Couleurs :
- Fond app `#fbfbfd` ; surfaces `#ffffff` ; surface secondaire `#f0f0f4` ; bordures `#ececf1` ; pointillés `#d5d5de`
- Texte principal `#17171f` ; secondaire `#71717d` ; tertiaire `#a5a5b0`
- Accent primaire (indigo) `#5b5bd6`, fond teinté `#ececfa`
- Catégories : Identité `#5b5bd6`/`#ececfa` · Santé `#1e8f6e`/`#e2f4ed` · Voyage `#b3762a`/`#faf0df` · Finances/destructif `#c15c9a`/`#f9e9f3`
Typo : système (SF Pro sur iOS / Roboto sur Android). Titres 30–34px/800 (ls -0.03em), titres d'écran 24px/800, corps 15–16px, secondaire 13–14px, légendes 12px, chips 10.5–13px/600.
Espacement : padding écran 20px latéral ; gaps 8/10/12px ; padding-top de contenu 64px (zone barre d'état).
Radius : cartes 16–18px, aperçus 12–20px, boutons 16px, chips/pilules 999px, sheet 28px.
Ombres : CTA `0 10px 24px rgba(91,91,214,.25)` ; cartes `0 1px 3px rgba(23,23,31,.04)` ; pilule noire `0 10px 24px rgba(23,23,31,.25)`.

## Assets
Aucun asset externe : les vignettes de documents sont des placeholders (rayures diagonales) à remplacer par les vraies miniatures chiffrées ; icônes = formes géométriques simples, à remplacer par la bibliothèque d'icônes du projet (SF Symbols / Material Symbols). Le cadre iPhone (`ios-frame.jsx`) sert uniquement à la présentation.

## Fichiers
- `Sésame Variations.dc.html` — toutes les maquettes. Turn 2 (haut de page) = écrans finaux 1c ; turn 1 = exploration (1a, 1b écartées ; 1c retenue).
- `ios-frame.jsx` — composant de cadre iPhone (présentation seulement, ne pas implémenter).
- `support.js` — runtime de prévisualisation (ignorer).
