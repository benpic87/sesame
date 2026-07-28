# Politique de confidentialité — Sésame

*Dernière mise à jour : 28 juillet 2026*

## En une phrase

Sésame ne collecte, ne transmet et ne vend **aucune donnée** — l'application fonctionne entièrement sur votre appareil, sans compte et sans serveur.

## Ce que fait l'application

Sésame est un coffre-fort de documents 100 % local :

- **Vos documents** (images, PDF, notes) sont chiffrés (AES-256-GCM) sur votre appareil, avant toute écriture sur le disque. La clé de chiffrement est stockée dans le trousseau sécurisé (Keychain) de votre iPhone et ne quitte jamais l'appareil.
- **Aucune requête réseau** n'est émise par l'application. Pas de compte, pas de cloud, pas de synchronisation, pas de statistiques d'usage, pas de publicité, pas de SDK tiers.
- **Le répertoire du coffre est exclu des sauvegardes** iCloud/iTunes. Si vous exportez une sauvegarde manuelle, elle est chiffrée par une phrase de passe que vous seul connaissez, et vous choisissez vous-même où la stocker.

## Données traitées localement (jamais transmises)

| Donnée | Usage | Stockage |
|---|---|---|
| Documents et vignettes | Contenu de votre coffre | Chiffrés sur l'appareil uniquement |
| Code PIN / mot de passe | Déverrouillage | Seule une empreinte cryptographique (PBKDF2) est conservée, dans le Keychain |
| Face ID | Déverrouillage | Traité par iOS ; l'app ne voit qu'un « oui/non », jamais vos données biométriques |
| Catégories, noms, dates | Organisation du coffre | Base locale sur l'appareil |

## Autorisations demandées

- **Appareil photo** : scanner ou photographier un document. Les images sont chiffrées immédiatement et ne sont enregistrées nulle part ailleurs.
- **Photothèque** : importer un document ; l'app peut, à votre demande explicite, supprimer l'original non chiffré de la galerie.
- **Face ID** : déverrouiller le coffre.

Chaque autorisation est facultative et ne sert qu'à la fonction décrite.

## Achats intégrés

L'achat « Sésame Premium » est traité entièrement par Apple (App Store / StoreKit). Sésame ne reçoit ni votre identité, ni votre moyen de paiement, ni votre adresse — uniquement la confirmation anonyme que l'achat est actif sur cet appareil.

## Vos droits

Toutes vos données étant exclusivement sur votre appareil et sous votre contrôle :

- **Consulter / exporter** : Réglages ▸ Sauvegarde chiffrée locale.
- **Supprimer** : supprimez un document, utilisez « Effacer tout le coffre », ou désinstallez l'application — tout est effacé définitivement. Nous ne pouvons rien récupérer pour vous : nous n'avons jamais eu vos données.

## Modifications

Toute modification de cette politique sera publiée à cette adresse avec une nouvelle date. La promesse fondatrice — aucune collecte de données — ne changera pas : c'est l'architecture même de l'application.

## Contact

Questions : benoit.picard1@gmail.com

---

# Privacy Policy — Sésame (English)

*Last updated: July 28, 2026*

**In one sentence:** Sésame collects, transmits and sells **no data whatsoever** — the app runs entirely on your device, with no account and no server.

- All documents are encrypted (AES-256-GCM) on device before touching the disk; the key lives in your iPhone's Keychain and never leaves the device.
- The app makes **no network requests**. No account, no cloud, no analytics, no ads, no third-party SDKs.
- PIN/password: only a cryptographic hash (PBKDF2) is stored. Face ID is handled by iOS; the app only receives a yes/no.
- Permissions (camera, photo library, Face ID) are optional and used solely for the stated feature. Original photos are deleted from your gallery only at your explicit request.
- The "Sésame Premium" purchase is handled entirely by Apple; the app never sees your identity or payment details.
- Your data is exclusively on your device: delete a document, wipe the vault, or uninstall the app and everything is permanently erased. We cannot recover anything — we never had your data.

Contact: benoit.picard1@gmail.com
