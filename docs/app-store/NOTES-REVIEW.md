# Notes pour la review Apple (à coller dans « App Review Information »)

À coller telles quelles (en anglais — la review est plus rapide en anglais) :

```
REVIEW NOTES — Sésame (Document Vault)

No account or login exists in this app, by design: it is a 100% local,
offline document vault. There is nothing to sign into and no demo account
to provide. The app makes no network requests (you can verify with a proxy):
the only network traffic is Apple's own StoreKit.

HOW TO TEST
1. First launch: onboarding → create a 6-digit PIN (any, e.g. 123456).
   Face ID is optional and falls back to the PIN.
2. Add documents: tap "+", use "Import a file" or "New note" (camera and
   scanner require a physical device). Everything is encrypted with AES-GCM
   before being written to disk.
3. Free tier: the vault is limited to 3 documents. Adding a 4th opens the
   paywall.
4. IN-APP PURCHASE "Sésame Premium" (app.sesame.premium, non-consumable):
   unlocks unlimited documents. "Restore purchases" is available on the
   paywall and in Settings.
5. Secure sharing: open a document → share → an encrypted archive is
   created with a generated password (to be communicated separately).

PERMISSIONS EXPLAINED
- Camera: scanning/photographing documents (VisionKit / UIImagePickerController).
  Images are encrypted immediately and never leave the device.
- Photo library: importing documents; the app OFFERS to delete the
  unencrypted original after import (user choice, system confirmation).
- Face ID: unlocking the vault (LocalAuthentication).

PRIVACY
No data is collected. No third-party SDK, no analytics, no ads.
The vault directory is excluded from backups; every file (including
thumbnails) is individually encrypted with a key stored in the Keychain
(kSecAttrAccessibleWhenUnlockedThisDeviceOnly).

Auto-lock: the app relocks after 60 s of inactivity and whenever it goes
to the background — this is expected behavior, not a bug.
```

## Informations de contact review

| Champ | Valeur |
|---|---|
| Prénom / Nom | Benoît Picard |
| Téléphone | *(votre numéro, format international)* |
| E-mail | benoit.picard1@gmail.com |
| Compte de démo | **Non requis** — cocher « Sign-in required : No » |

## Capture d'écran de l'achat intégré

L'achat intégré exige sa propre capture pour la review : utiliser une capture de l'écran Premium (paywall) de l'app, prise dans le simulateur.
