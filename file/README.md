# Fixed Price DEX with Token Vault

## Overview
This project implements a simple fixed-price DEX and a secure token vault on the Stacks blockchain.  
It follows the SIP-010 fungible token standard.

### Contracts
- `token-a.clar`: Example SIP-010 token.
- `token-b.clar`: Example SIP-010 token.
- `dex.clar`: Fixed-rate DEX with improved validation and security checks.
- `vault.clar`: Simple token vault for deposits and withdrawals.
- `traits/sip-010-trait.clar`: Imported SIP-010 trait.

---

## Phase 2 Features
- **DEX Enhancements**
  - Swap fees added (default: 1% sent to contract owner).
  - Rejects swaps of `0` tokens.
  - Ensures only SIP-010 compliant tokens are used.
  - Security improvements to reduce risk of misuse.

- **Vault Contract**
  - Deposit SIP-010 tokens into the vault.
  - Withdraw tokens securely.
  - Balances tracked per user.
  - Only the depositor can withdraw.

---

## Usage

### Deploying Contracts
```sh
clarinet check
clarinet console
