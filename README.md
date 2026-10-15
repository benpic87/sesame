# Sésame

Coffre-fort de documents **100 % local** pour iOS : aucun cloud, aucun compte, aucun serveur, aucune requête réseau. Passeports, cartes, PDF et notes sont chiffrés individuellement sur l'appareil.

Design : direction « Pop clair » du handoff (`design_handoff_sesame/README.md`), recréée en SwiftUI.

## Prérequis

- Xcode 16+ (macOS), iOS 17 minimum, Swift 5.10+
- Aucune dépendance externe : uniquement les frameworks système (SwiftUI, SwiftData, CryptoKit, LocalAuthentication, VisionKit, PhotosUI, PDFKit)

Ouvrir `Sesame.xcodeproj`, sélectionner un simulateur ou un appareil, ⌘R. Tests : ⌘U (cibles `SesameTests`). Le projet utilise les groupes synchronisés d'Xcode 16 : tout fichier ajouté sous `Sesame/` ou `SesameTests/` est automatiquement inclus dans la cible.

> Note : Face ID et l'appareil photo nécessitent un appareil réel (le simulateur permet de tester le PIN et les imports de fichiers).

## Architecture

MVVM léger : les vues SwiftUI observent des services injectés par l'environnement (`@Environment`), les listes passent par `@Query` (SwiftData) pour la mise à jour automatique.

```
Sesame/
├── SesameApp.swift          Point d'entrée, ModelContainer, verrouillage au passage en arrière-plan
├── Models/                  Document, Category (SwiftData) — un document ⇄ plusieurs étiquettes
├── Services/
│   ├── CryptoService.swift  AES-GCM ; clé maîtresse 256 bits dans le Keychain
│   │                        (kSecAttrAccessibleWhenUnlockedThisDeviceOnly) ;
│   │                        conteneurs à phrase de passe (PBKDF2-HMAC-SHA256, 210 000 itérations)
│   ├── AuthService.swift    Face ID → PIN (6 chiffres) → mot de passe ; AutoLockPolicy (logique pure testable)
│   ├── VaultStore.swift     Source de vérité : import chiffré, vignettes chiffrées, catégories,
│   │                        effacement ; répertoire du coffre exclu des sauvegardes (isExcludedFromBackup)
│   ├── ShareService.swift   Archive chiffrée .sesame, copie AirDrop temporaire, sauvegarde .sesamebackup
│   ├── StoreService.swift   Freemium StoreKit 2 : limite gratuite de 3 documents, achat unique Premium
│   ├── PassphraseGenerator.swift  Mots de passe « corail-lampe-92-nuit » (mot-mot-nombre-mot)
│   └── KeychainStore.swift  Accès Keychain injectable (InMemoryKeychain pour les tests)
├── Views/
│   ├── RootView.swift       Onboarding → verrouillage → coffre ; écran de garde dans l'app switcher
│   ├── Lock/                Déverrouillage (Face ID), pavé PIN, repli mot de passe
│   ├── Home/                Coffre : chips-filtres par catégorie, grille 2 colonnes, pilule « + Ajouter »
│   ├── Add/                 5 méthodes : scanner VisionKit (multi-pages → PDF), photo, galerie
│   │                        (avec proposition de suppression de l'original), fichier, note chiffrée
│   ├── Detail/              Aperçu, étiquettes éditables, métadonnées, alerte expiration (< 6 mois)
│   ├── Search/              Recherche temps réel par nom, filtres Tout/Images/PDF/Notes, surlignage
│   ├── Share/               Bottom sheet : archive chiffrée + mot de passe généré, ou AirDrop simple
│   ├── Settings/            Sécurité, catégories, sauvegarde chiffrée, langue, effacement (double confirmation)
│   └── Onboarding/          3 étapes : promesse locale-only → PIN/Face ID → premières catégories
├── Support/Theme.swift      Design tokens (couleurs, rayons, ombres, police mise à l'échelle Dynamic Type)
└── Resources/               Localizable.xcstrings (fr = langue source), Assets
```

## Publication App Store

Tout le dossier de soumission est dans [`docs/`](docs/) :
- [`docs/app-store/GUIDE-PUBLICATION.md`](docs/app-store/GUIDE-PUBLICATION.md) — parcours complet, du compte développeur à la review ;
- [`docs/app-store/FICHE-METADONNEES.md`](docs/app-store/FICHE-METADONNEES.md) — nom, description, mots-clés (FR + EN), réponses au questionnaire de confidentialité ;
- [`docs/app-store/NOTES-REVIEW.md`](docs/app-store/NOTES-REVIEW.md) — notes pour l'examinateur Apple ;
- [`docs/POLITIQUE-CONFIDENTIALITE.md`](docs/POLITIQUE-CONFIDENTIALITE.md) — politique de confidentialité (FR + EN) à publier via GitHub Pages.

La conformité export (`ITSAppUsesNonExemptEncryption = NO`) et l'icône 1024 px sont déjà dans le projet.

## Monétisation (freemium)

- **Version gratuite** : coffre limité à **3 documents** (toutes les autres fonctions restent ouvertes). Un bandeau sur l'accueil affiche le compteur ; le bouton « + Ajouter » ouvre l'écran Premium quand la limite est atteinte.
- **Sésame Premium** : achat unique non consommable `app.sesame.premium` (StoreKit 2, aucun SDK tiers, pas d'abonnement, pas de publicité) → documents illimités. Restauration des achats dans les Réglages et sur l'écran de vente.
- La limite ne s'applique qu'à l'**ajout** : si un achat est remboursé, les documents existants restent accessibles — jamais de données prises en otage.
- **Test local** : sélectionner `Sesame.storekit` dans le schéma (Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Options ▸ StoreKit Configuration) pour tester l'achat sans App Store Connect. En production, créer le produit `app.sesame.premium` dans App Store Connect.

## Localisation

L'interface est traduite en 11 langues : français (langue de développement), anglais, allemand, espagnol, italien, portugais (pt-PT), néerlandais, japonais, coréen, chinois simplifié et arabe (avec les 6 formes plurielles CLDR). Les chaînes du code sont les clés françaises ; les traductions vivent dans `Resources/Localizable.xcstrings`. L'arabe bénéficie automatiquement de la disposition droite-à-gauche gérée par SwiftUI.

## Sécurité

- **Clé maîtresse** : 256 bits, stockée dans le Keychain avec `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (jamais synchronisée, jamais migrée). Chargée au premier usage ; créée uniquement si le Keychain confirme son absence (`errSecItemNotFound`), jamais écrasée, et utilisée seulement une fois son enregistrement réussi. Un Keychain momentanément inaccessible fait échouer l'opération sans jamais remplacer la clé.
- **Fichiers** : chaque document et chaque vignette est chiffré individuellement en AES-GCM avant toute écriture disque (`.completeFileProtection` en plus). Le contenu des documents n'est jamais écrit en clair.
- **Métadonnées** : noms, dates, tailles et étiquettes sont dans la base SwiftData `Vault/Sesame.store`, protégée par le chiffrement d'iOS (Data Protection) mais **pas** par la clé de l'app. Tout le répertoire `Application Support/Vault` (fichiers et base) est exclu des sauvegardes iCloud et ordinateur ; l'ancienne base `default.store` y est déplacée au lancement.
- **PIN / mot de passe** : jamais stockés — seulement une empreinte PBKDF2 salée dans le Keychain, comparée à temps constant. Toutes les 5 erreurs, attente croissante (30 s, 1 min, 2 min… 1 h max), conservée dans le Keychain : relancer l'app ne remet pas le compteur à zéro.
- **Limite assumée** : le PIN et Face ID verrouillent l'interface ; ils ne servent pas à dériver la clé. Le chiffrement protège contre la lecture du stockage (appareil verrouillé, sauvegardes, autres apps), pas contre quelqu'un qui contrôle déjà un iPhone déverrouillé et compromis.
- **Verrouillage** : automatique après 60 s d'inactivité (délai réglable : 30 s à 5 min) et immédiat à chaque passage en arrière-plan ; le contenu est masqué dans le sélecteur d'apps.
- **Partage chiffré** : le format `.sesame` (et `.sesamebackup` pour la sauvegarde) est un conteneur autoportant : `"SESAME01"` ‖ sel 16 octets ‖ AES-GCM (nonce + chiffré + tag). Clé dérivée de la phrase de passe par PBKDF2-HMAC-SHA256 (210 000 itérations). Le mot de passe généré doit être communiqué **par un autre canal**. (La maquette évoquait un « .zip + mot de passe » : le format zip AES nécessiterait une dépendance tierce, exclue par les contraintes ; le conteneur documenté ci-dessus assure la même garantie et reste importable.)
- **AirDrop simple** : copie déchiffrée temporaire, supprimée dès la fermeture de la share sheet (chiffrée en transit par AirDrop lui-même).

## Tests

`SesameTests` couvre :
- `CryptoServiceTests` : aller-retour chiffrer/déchiffrer, rejet de clé erronée, détection d'altération, persistance de la clé maîtresse, conteneurs à phrase de passe, empreintes PIN.
- `AutoLockTests` : politique d'auto-verrouillage (délai, report par activité), déverrouillage PIN/mot de passe.
- `PassphraseGeneratorTests` : format « mot-mot-nombre-mot ».

## Sauvegarde et restauration

- **Export** (Réglages ▸ Sauvegarde chiffrée locale) : conteneur `.sesamebackup` chiffré par une phrase de récupération générée, à enregistrer où l'on veut via Fichiers (y compris iCloud Drive, au choix de l'utilisateur).
- **Restauration** (Réglages ▸ Restaurer une sauvegarde) : fusion dans le coffre existant — catégories rapprochées par identifiant puis par nom, documents déjà présents (même nom, taille et date d'ajout) ignorés, contenus rechiffrés avec la clé maîtresse locale de l'appareil. La restauration n'est pas bloquée par la limite gratuite (les données de l'utilisateur ne sont jamais prises en otage) ; seule l'*ajout* de nouveaux documents reste soumis à la limite.

## Hors périmètre v1

Mode sombre, iPad, ouverture des fichiers `.sesame` reçus.
