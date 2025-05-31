

# STX-CollatX - Synthetic Asset Smart Contract

This smart contract implements a **decentralized synthetic asset issuance platform** on the Stacks blockchain. It allows users to lock collateral (in STX), mint synthetic tokens based on real-world asset prices, and interact with these tokens through transfers, redemptions, and liquidation mechanisms.

---

## 🚀 Features

* 🏦 **Minting Synthetic Tokens:** Users can lock STX as collateral and mint synthetic tokens based on the current price feed.
* 🪙 **Token Transfers:** Transfer synthetic tokens securely between accounts.
* 📉 **Burning Tokens:** Users can redeem synthetic tokens to reclaim collateral.
* 📊 **Price Oracle Integration:** Admin-controlled price feed ensures up-to-date pricing for collateral calculations.
* 🔐 **Collateral Safety & Liquidation:** Tracks and enforces collateral ratios to protect against under-collateralization.
* 🧮 **Overflow-Protected Math:** All arithmetic operations are validated against overflows.

---

## 🧱 Architecture

### 📁 Data Structures

* **Maps**

  * `user-token-holdings`: Tracks balances of synthetic tokens per user.
  * `collateralized-positions`: Stores vault info for each user (collateral, token amount, entry price).

* **Variables**

  * `oracle-update-block-height`: Timestamp of last oracle update.
  * `current-market-price`: Price of underlying asset.
  * `global-token-supply`: Total synthetic tokens in circulation.

---

## ⚙️ Key Constants

| Constant                              | Description                                           |
| ------------------------------------- | ----------------------------------------------------- |
| `COLLATERAL-SAFETY-RATIO (150%)`      | Required over-collateralization for minting           |
| `COLLATERAL-LIQUIDATION-RATIO (120%)` | Threshold below which positions are liquidated        |
| `MIN-TOKEN-ISSUANCE-AMOUNT`           | Minimum amount of synthetic tokens that can be minted |
| `PRICE-VALIDITY-PERIOD-BLOCKS`        | Price freshness window (15 minutes)                   |
| `MAX-ALLOWED-PRICE`                   | Cap to avoid unrealistic oracle inputs                |

---

## 🧮 Math Utilities

### `secure-add`, `secure-subtract`, `secure-multiply`

Used to prevent arithmetic overflows in financial operations.

---

## 📤 Public Functions

### ✅ `set-price-feed-value (new-price)`

**Admin-only** function to update the current market price of the underlying asset.

---

### ✅ `create-synthetic-tokens (token-amount)`

Allows users to mint synthetic tokens by depositing sufficient STX collateral based on the safety ratio.

---

### ✅ `destroy-synthetic-tokens (token-amount)`

Allows users to burn their tokens and withdraw a proportional amount of collateral.

---

### ✅ `send-synthetic-tokens (recipient, amount)`

Transfers synthetic tokens from one user to another.

---

### ✅ `add-collateral (collateral-amount)`

Users can top-up their vault with more STX to increase safety or prepare for minting more tokens.

---

### ✅ `force-close-position (position-owner)`

Allows anyone to liquidate an under-collateralized position (<120% ratio) and claim the staked collateral.

---

## 🕵️ Read-Only Functions

* `get-user-token-balance(account-holder)` – Get balance of synthetic tokens.
* `get-circulating-supply()` – Current total supply of synthetic tokens.
* `get-market-price()` – Latest oracle-reported price.
* `get-position-details(account-holder)` – Vault info for a user.
* `calculate-position-health-ratio(account-holder)` – Collateral health score (e.g. 150 = 150%).

---

## ❌ Error Codes

| Error      | Meaning                    |
| ---------- | -------------------------- |
| `err u100` | Unauthorized access        |
| `err u101` | Insufficient token balance |
| `err u102` | Token amount too low       |
| `err u103` | Stale oracle data          |
| `err u104` | Not enough collateral sent |
| `err u105` | Collateral below threshold |
| `err u106` | Oracle price too high/low  |
| `err u107` | Arithmetic overflow        |
| `err u108` | Invalid transfer recipient |
| `err u109` | Amount must be positive    |
| `err u110` | No open vault found        |

---

## 🛡️ Security Considerations

* **Overflow Prevention:** All arithmetic operations use safe wrappers.
* **Oracle Freshness Check:** Ensures price isn't outdated before minting.
* **Permission Control:** Only admin can set price feed values.
* **Liquidation Enforcement:** Anyone can force-close under-collateralized vaults.

---

## 🧪 Test Scenarios

1. **Mint and Burn**

   * User mints tokens with STX → Burns tokens → Receives proportional STX back.

2. **Transfer Tokens**

   * User A sends tokens to User B; balances adjust correctly.

3. **Collateralization Ratio Drop**

   * Admin lowers price → Another user force-closes the unhealthy vault.

---

