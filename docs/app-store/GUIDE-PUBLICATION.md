# Guide de publication — Sésame sur l'App Store

Parcours complet, dans l'ordre. Prérequis matériel : un Mac avec Xcode 16+ pour les étapes 5–7 (archive et envoi). Tout le reste se fait dans un navigateur.

---

## 1. Compte développeur Apple

1. Créer un compte sur [developer.apple.com](https://developer.apple.com) avec votre identifiant Apple.
2. Adhérer à l'**Apple Developer Program** : 99 $ US/an (≈ 99 €). Compter 24–48 h de validation.
3. Type de compte : **Individuel** suffit (le nom du vendeur affiché sera votre nom). Une entreprise exige un numéro D-U-N-S.

## 2. Identifiants et signature

1. Dans [developer.apple.com/account](https://developer.apple.com/account) ▸ *Certificates, Identifiers & Profiles* ▸ *Identifiers* ▸ **+** :
   - Type : App IDs ▸ App.
   - Bundle ID **explicite** : `app.sesame.Sesame` (doit correspondre au projet Xcode — c'est déjà la valeur configurée).
   - Capabilities : rien à cocher (pas de Push, pas d'iCloud — c'est le principe de l'app). L'in-app purchase est actif par défaut.
2. La signature est en mode **automatique** dans le projet : sur Mac, Xcode ▸ cible Sesame ▸ Signing & Capabilities ▸ sélectionner votre *Team*. Xcode crée certificats et profils tout seul.

## 3. Fiche App Store Connect

Dans [appstoreconnect.apple.com](https://appstoreconnect.apple.com) ▸ *Apps* ▸ **+** ▸ *Nouvelle app* :

| Champ | Valeur |
|---|---|
| Plateforme | iOS |
| Nom | `Sésame — Coffre de documents` (le nom seul « Sésame » est probablement déjà pris ; le nom doit être unique sur tout l'App Store) |
| Langue principale | Français (France) |
| Bundle ID | `app.sesame.Sesame` |
| SKU | `sesame-ios-001` (identifiant interne libre, invisible du public) |
| Accès utilisateur | Accès complet |

Puis remplir la fiche avec le contenu prêt à coller de **[FICHE-METADONNEES.md](FICHE-METADONNEES.md)** : description, sous-titre, mots-clés, catégories (Utilitaires + Productivité), classification 4+, URLs.

## 4. Achat intégré (Sésame Premium)

Dans la fiche de l'app ▸ *Monétisation* ▸ *Achats intégrés* ▸ **+** :

| Champ | Valeur |
|---|---|
| Type | **Non consommable** |
| Nom de référence | `Premium` |
| ID produit | `app.sesame.premium` — **doit être exactement celui-ci** (codé dans `StoreService.swift`) |
| Prix | Niveau ≈ 4,99 € (ajustable) |
| Nom affiché (fr) | `Sésame Premium` |
| Description (fr) | `Coffre illimité, pour toujours` |

⚠️ Deux pièges classiques de premier envoi :
- Joindre une **capture d'écran de review** à l'achat intégré (une capture de l'écran Premium de l'app suffit).
- Lors de la première soumission, **cocher l'achat intégré pour qu'il parte avec le binaire** (section « Achats intégrés » de la version dans App Store Connect). Un IAP jamais soumis = achat qui échoue en production.

## 5. Icône de l'app — ✅ déjà en place

Une icône 1024 × 1024 px reprenant le logo (cercle indigo `#5b5bd6`, carré arrondi blanc, fond `#fbfbfd`) est déjà dans `Sesame/Resources/Assets.xcassets/AppIcon.appiconset`. Elle est fonctionnelle pour la soumission ; libre à vous de la remplacer par une version de designer plus tard (même fichier, mêmes contraintes : PNG sans transparence, coins droits — Apple arrondit lui-même).

## 6. Captures d'écran

Obligatoires pour un iPhone 6,9" (1320 × 2868 px) — faites depuis le simulateur iPhone 16 Pro Max (⌘S). Minimum 1, recommandé 5 :
1. Accueil / Coffre avec quelques documents ;
2. Écran de déverrouillage ;
3. Ajout (les 5 méthodes) ;
4. Partage sécurisé avec mot de passe généré ;
5. Détail d'un document.

Ne jamais montrer de vrais documents d'identité — créer des documents factices (« Passeport – Camille » comme dans les maquettes). Optionnel : versions localisées des captures pour les 11 langues (les captures FR sont utilisées par défaut pour les autres langues sinon).

## 7. Compilation et envoi (sur Mac)

```bash
# Vérifier que tout passe d'abord
xcodebuild test -project Sesame.xcodeproj -scheme Sesame \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Puis dans Xcode : sélectionner **Any iOS Device (arm64)** ▸ Product ▸ **Archive** ▸ fenêtre Organizer ▸ **Distribute App** ▸ App Store Connect ▸ Upload. Le binaire apparaît dans App Store Connect ▸ TestFlight après ~15 min de traitement.

**Conformité à l'export (chiffrement)** : déjà réglée dans le projet — `ITSAppUsesNonExemptEncryption = NO` est déclaré dans les réglages de build. Sésame n'utilise que le chiffrement standard d'Apple (CryptoKit/AES) pour protéger les données locales de l'utilisateur, ce qui relève de l'exemption « mass market » ; aucune question ne sera posée à l'upload.

## 8. TestFlight (recommandé avant soumission)

Dans App Store Connect ▸ TestFlight : s'ajouter comme testeur interne et vérifier **sur un vrai iPhone** ce que la CI ne peut pas tester :
- [ ] Face ID (déverrouillage, repli PIN, fallback dans la boîte de dialogue)
- [ ] Scanner VisionKit (recadrage, multi-pages → PDF)
- [ ] Appareil photo et import galerie (+ proposition de suppression de l'original)
- [ ] AirDrop réel vers un autre appareil (les deux modes)
- [ ] **Parcours d'achat Premium en sandbox** (compte de test : App Store Connect ▸ Utilisateurs et accès ▸ Sandbox)
- [ ] Verrouillage à la mise en arrière-plan + masquage dans le sélecteur d'apps
- [ ] Les 11 langues (Réglages iOS ▸ Sésame ▸ Langue) et la disposition droite-à-gauche en arabe

## 9. Soumission à la review

1. Fiche de la version 1.0 : joindre le build, les captures, cocher l'achat intégré.
2. Section **Confidentialité de l'app** : répondre au questionnaire — réponses exactes dans [FICHE-METADONNEES.md § Confidentialité](FICHE-METADONNEES.md).
3. **URL de politique de confidentialité** (obligatoire) : publier `docs/POLITIQUE-CONFIDENTIALITE.md` — le plus simple est GitHub Pages sur ce dépôt (Settings ▸ Pages ▸ Deploy from branch ▸ main /docs), ce qui donne une URL du type `https://benpic87.github.io/sesame/POLITIQUE-CONFIDENTIALITE`.
4. **Notes pour la review** : coller le contenu de [NOTES-REVIEW.md](NOTES-REVIEW.md) (explique à l'examinateur qu'il n'y a pas de compte, comment tester, pourquoi les permissions).
5. Soumettre. Première review : 24–72 h en général.

## 10. Motifs de rejet plausibles et parades (déjà anticipés)

| Guideline | Risque | Parade en place |
|---|---|---|
| 2.1 Complétude | IAP non testable | Notes de review + IAP joint à la soumission |
| 3.1.1 Paiements | Achat hors App Store | Aucun — StoreKit uniquement, bouton restaurer présent |
| 5.1.1 Confidentialité | Permissions injustifiées | Purpose strings caméra/photos/Face ID explicites et honnêtes |
| 2.3.7 Métadonnées | Nom d'app générique déjà pris | Utiliser « Sésame — Coffre de documents » |
| 4.0 Design | App « trop simple » | Peu probable : fonctionnalité réelle et complète |

## Récapitulatif des coûts et délais

| Poste | Coût | Délai |
|---|---|---|
| Apple Developer Program | 99 $/an | 24–48 h |
| Icône 1024 px | à produire | — |
| Archive + upload (Mac requis) | — | 1 h |
| TestFlight | gratuit | 15 min de traitement |
| Review Apple | gratuit | 24–72 h |
