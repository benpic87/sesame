# Fiche App Store — contenu prêt à coller

## Français (langue principale)

**Nom** (30 car. max)
```
Sésame — Coffre de documents
```

**Sous-titre** (30 car. max)
```
Vos papiers, chiffrés, ici.
```

**Texte promotionnel** (170 car. max, modifiable sans re-review)
```
Passeports, ordonnances, contrats : tout chiffré sur votre iPhone. Pas de compte, pas de cloud, pas de trace.
```

**Description**
```
Sésame garde vos documents sensibles — passeports, cartes, ordonnances, contrats, notes — chiffrés sur votre iPhone. Et seulement là.

100 % LOCAL, 0 % CLOUD
• Aucun compte, aucun serveur, aucune requête réseau
• Chiffrement AES sur l'appareil, clé protégée par la puce sécurisée
• Rien ne quitte votre téléphone, jamais

VERROUILLÉ, VRAIMENT
• Face ID, code PIN à 6 chiffres ou mot de passe
• Verrouillage automatique après 60 secondes d'inactivité
• Contenu masqué dans le sélecteur d'apps
• Protection anti-force brute

TOUT AJOUTER EN QUELQUES SECONDES
• Scanner avec recadrage automatique des bords
• Photo, galerie (avec suppression de l'original), fichiers PDF
• Notes texte chiffrées : codes, numéros, mémos

ORGANISÉ À VOTRE FAÇON
• Étiquettes colorées multiples par document
• Recherche instantanée par nom
• Alerte quand un document approche de son expiration

PARTAGE SÉCURISÉ
• Archive chiffrée avec mot de passe généré, à communiquer par un autre canal
• Ou envoi AirDrop direct
• Sauvegarde chiffrée manuelle vers Fichiers — jamais automatique

VERSION GRATUITE : 3 documents. Sésame Premium (achat unique, pas d'abonnement) : documents illimités.

Sésame ne collecte aucune donnée. Pas de pub, pas de traqueurs, pas de statistiques. Votre vie privée n'est pas un réglage, c'est l'architecture.
```

**Mots-clés** (100 car. max, séparés par des virgules, sans espaces)
```
coffre,documents,passeport,scanner,sécurité,chiffré,privé,carte,identité,pdf,confidentiel,local
```

**URLs**
| Champ | Valeur |
|---|---|
| URL d'assistance | `https://github.com/benpic87/sesame` (ou votre site) |
| URL marketing (optionnel) | — |
| Politique de confidentialité | `https://benpic87.github.io/sesame/POLITIQUE-CONFIDENTIALITE` (après activation de GitHub Pages) |

**Catégories** : principale **Utilitaires**, secondaire **Productivité**
**Classification** : questionnaire → toutes réponses « Non » → **4+**
**Copyright** : `© 2026 Benoît Picard`
**Tarif** : Gratuit (+ achat intégré Sésame Premium)

---

## English (à saisir dans la langue « Anglais (É.-U.) »)

**Name**
```
Sésame — Document Vault
```

**Subtitle**
```
Your papers, encrypted, here.
```

**Promotional text**
```
Passports, prescriptions, contracts: all encrypted on your iPhone. No account, no cloud, no trace.
```

**Description**
```
Sésame keeps your sensitive documents — passports, cards, prescriptions, contracts, notes — encrypted on your iPhone. And only there.

100% LOCAL, 0% CLOUD
• No account, no server, no network requests
• On-device AES encryption, key protected by the secure enclave
• Nothing ever leaves your phone

TRULY LOCKED
• Face ID, 6-digit PIN or password
• Auto-lock after 60 seconds of inactivity
• Content hidden in the app switcher
• Brute-force protection

ADD ANYTHING IN SECONDS
• Scanner with automatic edge cropping
• Photos, gallery (with original deletion), PDF files
• Encrypted text notes: codes, numbers, memos

ORGANIZED YOUR WAY
• Multiple color tags per document
• Instant search by name
• Alert when a document nears expiration

SECURE SHARING
• Encrypted archive with a generated password to share through another channel
• Or direct AirDrop
• Manual encrypted backup to Files — never automatic

FREE VERSION: 3 documents. Sésame Premium (one-time purchase, no subscription): unlimited documents.

Sésame collects no data. No ads, no trackers, no analytics. Your privacy isn't a setting — it's the architecture.
```

**Keywords**
```
vault,documents,passport,scanner,security,encrypted,private,card,identity,pdf,confidential,offline
```

> Les fiches pour les 9 autres langues (de, es, it, pt, nl, ja, ko, zh-Hans, ar) peuvent être générées sur demande — l'app elle-même est déjà traduite.

---

## Questionnaire « Confidentialité de l'app » (App Privacy)

Réponses exactes à donner :

1. **« Collectez-vous des données depuis cette app ? »** → **Non.**

C'est tout. Justification (si Apple demande des précisions) :
- Tous les documents sont chiffrés et stockés uniquement sur l'appareil ; aucune donnée ne quitte l'app.
- Aucun SDK tiers, aucun analytics, aucune requête réseau émise par le code de l'app.
- L'achat intégré est traité par StoreKit/Apple ; l'app ne voit ni identité ni moyen de paiement.

Résultat affiché sur la fiche : **« Aucune donnée collectée »** — cohérent avec le pied de page des Réglages de l'app.

## Conformité export (chiffrement)

Déjà déclaré dans le projet : `ITSAppUsesNonExemptEncryption = NO`. L'app n'utilise que le chiffrement standard du système (CryptoKit/AES) pour protéger les données locales de l'utilisateur — catégorie exemptée. Aucune démarche supplémentaire à l'upload.
