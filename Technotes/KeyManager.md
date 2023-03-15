## Key Manager
UI for planet key management.

## Features
- List all my planets from current library location, automatically updates when new planets are added or removed.
- Show planet key information, including:
  - Planet Name
  - Key Name
  - Key ID
  - Status: if key is stored in the IPFS Keystore
  - Status: if key is stored in the Keychain
- Key management:
  - Sync Action (only if key is stored in IPFS Keystore or Keychain)
    - Sync key from IPFS Keystore to Keychain
    - Sync key from Keychain to IPFS Keystore
  - Import Action (only if key is not stored in IPFS Keystore)
    - Import key file to IPFS Keystore and Keychain (The key must has the same key id, otherwise it will fail.)
  - Export Action (only if key is stored in IPFS Keystore)
    - Export key file from IPFS Keystore
    - Key format: pem-pkcs8-cleartext
    - Key type: ed25519
    - Key name: [Planet Name].pem
  - Reload Action
    - Reload automatically if my planets are changed

## Implementation
- The core features (sync, import, export) of Key Manager are implemented in the new ```KeychainHelper.swift```, it also supports other password operations like saving API passcode.
- UI related features like reload are implemented in ```PlanetKeyManagerViewModel.swift```.
- When saving into Keychain, the default key for iCloud Keychain Sync is set to ```true```. Syncing between devices is enabled by default, however in current implementation you might have to manually import key file to the new device.
