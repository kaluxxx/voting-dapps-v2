# Application de Vote Décentralisée (dApp) avec Intégration NFT

Une application de vote décentralisée robuste construite avec Solidity et Foundry, intégrant des droits de vote basés sur des NFT, le financement des candidats et un workflow contrôlé.

## Fonctionnalités

- **Vote basé sur les NFT** : Un NFT = Un Vote. Les droits de vote sont représentés par des tokens ERC721 mintés lors du vote.
- **Gestion du Workflow** : Phases d'élection strictement contrôlées (Enregistrement des candidats -> Financement -> Vote -> Terminé).
- **Système de Candidats** :
  - Les administrateurs peuvent ajouter/mettre à jour/supprimer des candidats.
  - Les candidats peuvent recevoir des financements (ETH) de la part d'investisseurs (Rôle Founder).
  - Les candidats peuvent retirer leurs fonds accumulés.
- **Contrôle d'accès basé sur les rôles** :
  - `ADMIN_ROLE` : Gère le déroulement de l'élection et les candidats.
  - `FOUNDER_ROLE` : Autorisé à financer les candidats.
- **Sécurité** : Construit avec `AccessControl`, `Ownable` et `ERC721` d'OpenZeppelin.

## Contrats Intelligents

### `Voting.sol`
Le contrat logique principal gérant :
- La machine à états du workflow électoral.
- L'enregistrement et la gestion des candidats.
- Le mécanisme de vote.
- La gestion des fonds pour les candidats.

### `VotingNFT.sol`
Un contrat ERC721 représentant la participation au vote.
- Nom du Token : "Voting Participation NFT" (VOTE)
- Minté automatiquement lorsqu'un utilisateur vote.
- Empêche le double vote (vérifié via `balanceOf`).

## Prérequis

- **Foundry** : Assurez-vous d'avoir Foundry installé.
  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```

## Installation

1. Cloner le dépôt :
   ```bash
   git clone <repo-url>
   cd voting-dapp-foundry
   ```

2. Installer les dépendances :
   ```bash
   forge install
   ```

3. Créer un fichier `.env` basé sur votre configuration :
   ```env
   SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/VOTRE-CLE
   PRIVATE_KEY=votre_clé_privée
   ```

## Utilisation

### Compiler
```bash
forge build
```

### Tester
```bash
forge test
```

### Déployer sur le Testnet (Sepolia)
Un script PowerShell est fourni pour un déploiement facile :
```powershell
.\deploy-testnet.ps1
```

## Informations de Déploiement (Sepolia)

**Date** : 17/12/2025

| Contrat | Adresse |
|---------|---------|
| **VotingNFT** | [`0x05734A847B98c9b0cf926AB5F2a41FaCCa625Ae1`](https://sepolia.etherscan.io/address/0x05734A847B98c9b0cf926AB5F2a41FaCCa625Ae1) |
| **Voting** | [`0xdcB81f6e251E58063Ba83b621fA7Ba152951CFd4`](https://sepolia.etherscan.io/address/0xdcB81f6e251E58063Ba83b621fA7Ba152951CFd4) |

### Transactions Récentes
- **Déploiement VotingNFT** : [Lien Tx](https://sepolia.etherscan.io/tx/0x8ee3b008549e1a1190d31e213b2b03b8b8022c05276133ada3ec24707c13ad75)
- **Déploiement Voting** : [Lien Tx](https://sepolia.etherscan.io/tx/0xd2ad50f1373bce1543bf5028548d4ad552261797896fe059ab477006c80ae4e4)
- **Ajout Candidat (Alice)** : [Lien Tx](https://sepolia.etherscan.io/tx/0x320ad11f21fa5d7db0a4f14b33f8ce2756085ad66f701e17f36c48b083ba4060)
- **Ajout Candidat (Bob)** : [Lien Tx](https://sepolia.etherscan.io/tx/0xcdadf868a5c274b7a49b64fafaa032200c465d7849838f0226c4431cb62390ac)
- **Changement Status (Found Candidates)** : [Lien Tx](https://sepolia.etherscan.io/tx/0xba8b86a3bc519be7176d8538a2282fcb5d966934bfebeb05d71c0ab26fd7de3f)
- **Grant Role (Founder)** : [Lien Tx](https://sepolia.etherscan.io/tx/0xc8dc2e068bf75b6e92cf4c925ecad6af776e261d088735b7453c5d0fe268730f)
- **Changement Status (Vote)** : [Lien Tx](https://sepolia.etherscan.io/tx/0xcfe908eff3e4d1af03482c2f98433e3532cd847c0393289df8ac782868af6fa8)
