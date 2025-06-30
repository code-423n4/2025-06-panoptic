# Panoptic audit details
- Total Prize Pool: $18,000 in USDC
  - HM awards: up to $14,400 in USDC
    - If no valid Highs or Mediums are found, the HM pool is $0 
  - QA awards: $600 in USDC
  - Judge awards: $2,500 in USDC
  - Scout awards: $500 USDC
- [Read our guidelines for more details](https://docs.code4rena.com/competitions)
- Starts June 27, 2025 20:00 UTC
- Ends July 7, 2025 20:00 UTC

**❗ Important notes for wardens** 
1. A coded, runnable PoC is required for all High/Medium submissions to this audit. 
   - This repo includes a basic template to run the test suite.
   - PoCs must use the test suite provided in this repo.
   - Your submission will be marked as Insufficient if the POC is not runnable and working with the provided test suite.
   - Exception: PoC is optional (though recommended) for wardens with signal ≥ 0.68.
2. Judging phase risk adjustments (upgrades/downgrades):
   - High- or Medium-risk submissions downgraded by the judge to Low-risk (QA) will be ineligible for awards.
   - Upgrading a Low-risk finding from a QA report to a Medium- or High-risk finding is not supported.
   - As such, wardens are encouraged to select the appropriate risk level carefully during the submission phase.

## Automated Findings / Publicly Known Issues

The 4naly3er report can be found [here](https://github.com/code-423n4/2025-06-panoptic/blob/main/4naly3er-report.md).

_Note for C4 wardens: Anything included in this `Automated Findings / Publicly Known Issues` section is considered a publicly known issue and is ineligible for awards._

### Administrative Risks

Managers and owners have a great deal of influence over the operations of the vault contract and the accountant contract -- these roles should be considered trusted such that issues requiring malicious intent, "user error", or action from anything other than an untrusted user are not valid.

In addition to the above:

- Users/managers can exploit rounding errors in repeated transfers/withdrawals/fulfillments to increase or decrease the performance fee paid
- Managers can artificially reduce the shares or assets received by users if they repeatedly partially fulfill deposits or withdrawals due to rounding
- Manager can provide stale pool price
- Manager can provide arrays with differing lengths

### Arithmetics

Performance fees may be under or over-charged.

Users may lose small amounts of funds due to rounding (in particular if their deposits/withdrawals are executed over many epochs) -- assume that 1 unit of underlying token always represents an inconsequential amount of value. 

It is assumed that the sum of the amount of underlying tokens in existence and the value of the vault does not exceed $2^{126} - 1$ at any point -- in general, issues requiring a large token supply or value as a prerequisite are not valid.

Additionally:

- Certain calculations may overflow/unsafe-cast-cutoff with a very large amount of tokens/shares present in the system
- Where quantities are stored in `uint128` variables, it is assumed that they will not overflow under normal conditions (unless there is a logic bug that abnormally updates them and causes an overflow)

### Operational Caveats

The oracle prices reported within the system might be stale, and this is a known risk. In relation to Net Asset Value (NAV) calculations, the vault's own calculation might not include all instruments of value controlled by the vault, and the pending Panoptic premium is accounted for in the vault's NAV.

It is assumed that the underlying token of a vault is always configured to a non-zero address that does not equate to the `0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE` address and is a valid EIP-20 token.

Finally, users may not be able to fulfill partial deposits/withdrawals if the remaining amount in that epoch is too small.

# Overview

Panoptic is the perpetual, oracle-free options protocol built on the Ethereum blockchain.

The Panoptic protocol consists of smart contracts on the Ethereum blockchain that handle the minting, trading, and market-making of perpetual put and call options. All smart contracts are available 24/7 and users can interact with the Panoptic protocol without the need for intermediaries like banks, brokerage firms, clearinghouses, market makers, or centralized exchanges.

Panoptic is the first permissionless options protocol that overcomes the technically challenging task of implementing an options protocol on the Ethereum blockchain. We achieve this by embracing the decentralized nature of Automated Market Makers and permissionless liquidity providing in Uniswap.

## Links

- **Previous audits:** While the scope has not undergone an audit directly, its dependencies have. All audits can be found [on the Panoptic website](https://panoptic.xyz/docs/security/security_audits), and below are some that concern the dependencies of the Panoptic project
    - [OpenZeppelin](https://panoptic.xyz/assets/files/OpenZeppelin_Panoptic-96437e260d5d0345fd6e1743af4ced8f.pdf)
    - [ABDK](https://panoptic.xyz/assets/files/ABDK_Panoptic-9b5f54f28ea969536eef4e3186bb13c9.pdf)
    - [Cantina](https://cantina.xyz/portfolio/5a11e7c3-da1e-4d0f-8700-bfc364d8b85a)
- **Documentation:** https://panoptic.xyz/docs/intro
- **Website:** https://panoptic.xyz/
- **X/Twitter:** https://x.com/panoptic_xyz 

---

# Scope

### Files in scope

| File   | SLOC | Purpose | Libraries used |
| ------ | --------------- | -----   | ------------ |
| [src/HypoVault.sol](https://github.com/code-423n4/2025-06-panoptic/blob/main/src/HypoVault.sol) | 272 | |lib/panoptic-v1.1/contracts/tokens/ERC20Minimal.sol, lib/panoptic-v1.1/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol, lib/panoptic-v1.1/contracts/base/Multicall.sol, lib/panoptic-v1.1/lib/openzeppelin-contracts/contracts/access/Ownable.sol, lib/panoptic-v1.1/lib/openzeppelin-contracts/contracts/utils/Address.sol, lib/panoptic-v1.1/contracts/libraries/Math.sol, lib/panoptic-v1.1/contracts/libraries/SafeTransferLib.sol|
| [src/accountants/PanopticVaultAccountant.sol](https://github.com/code-423n4/2025-06-panoptic/blob/main/src/accountants/PanopticVaultAccountant.sol) | 172 | |lib/panoptic-v1.1/lib/openzeppelin-contracts/contracts/access/Ownable.sol, lib/panoptic-v1.1/contracts/libraries/Math.sol, lib/panoptic-v1.1/contracts/libraries/PanopticMath.sol, lib/panoptic-v1.1/contracts/tokens/interfaces/IERC20Partial.sol, lib/panoptic-v1.1/contracts/interfaces/IV3CompatibleOracle.sol, lib/panoptic-v1.1/contracts/PanopticPool.sol, lib/panoptic-v1.1/contracts/types/LeftRight.sol, lib/panoptic-v1.1/contracts/types/LiquidityChunk.sol, lib/panoptic-v1.1/contracts/types/PositionBalance.sol, lib/panoptic-v1.1/contracts/types/TokenId.sol|
| **Totals** | **444** | | |

*For a machine-readable version, see [scope.txt](https://github.com/code-423n4/2025-06-panoptic/blob/main/scope.txt)*

### Files out of scope

| File         |
| ------------ |
| [src/interfaces/IVaultAccountant.sol](https://github.com/code-423n4/2025-06-panoptic/blob/main/src/interfaces/IVaultAccountant.sol) |
| [test/\*\*.\*\*](https://github.com/code-423n4/2025-06-panoptic/tree/main/test) |
| Totals: 3 |


*For a machine-readable version, see [out_of_scope.txt](https://github.com/code-423n4/2025-06-panoptic/blob/main/out_of_scope.txt)*

# Additional context

## Areas of concern (where to focus for bugs)

N/A

## Main invariants

### Deposit / Withdrawal Requirements

- Deposits and withdrawals made in the current epoch cannot be executed until the manager fulfills and advances the epoch
- Only deposits/withdrawals in the current epoch can be cancelled
- Only the manager can cancel or fulfill deposits/withdrawals
- A user with a deposit/withdrawal active in a given epoch should not have more than $\frac{amount * fulfilled}{total}$ (shares for withdrawals, assets for deposits) fulfilled in that epoch 
    - They may have funds in that epoch rolled over from previous epochs that won't be withdrawn until previous epochs are executed and the state is moved
- The fulfilled amount cannot exceed the deposited/withdrawn amount for a given epoch

## All trusted roles in the protocol

| Role                                | Description                       |
| --------------------------------------- | ---------------------------- |
| Hypovault Owner                          | Controls accountant, fee wallet, and manager address                |
| Hypovault Manager                             | Handles deposit/withdrawal execution and cna make arbitrary calls for vault management                       |
| Hypovault Fee Wallet | Receives performance fee tokens |
| Accountant Owner | Updates pool list on the accountant contract |


## Running tests

The codebase utilizes the `forge` framework for compiling its contracts and executing tests coded in `Solidity`.

### Prerequisites

- `forge` (`1.0.0-stable` tested)

### Setup

```bash
git clone https://github.com/code-423n4/2025-06-panoptic
cd 2025-06-panoptic
```

Install the project's dependencies as submodules:

```bash
git submodule update --init --recursive
```

### Tests

The codebase can now be compiled with the usual `build` command:

```bash 
forge build
```

Test execution does not require the `build` command to have been executed, and requires the following command:

```bash 
forge test 
```

### Creating a PoC

The project is composed of two core contracts; the `HypoVault` and the `PanopticVaultAccountant`. Within the codebase, we have introduced a `PoC.t.sol` test file that sets up each contract with mock implementations to allow PoCs to be constructed in a straightforward manner.

Depending on where the vulnerability lies, the PoC should either utilize the `vault` variable representing a `HypoVault` or the `accountant` variable representing the `PanopticVaultAccountant`.

For a submission to be considered valid, the test case **should execute successfully** via the following command:

```bash 
forge test --match-test submissionValidity
```

### Code Coverage

| File | % Lines | % Statements | % Branches | % Funcs |
| - | - | - | - | - |
| src/HypoVault.sol | 83.58% (112/134) | 85.03% (125/147) | 85.71% (6/7) | 70.00% (14/20) |
| src/accountants/PanopticVaultAccountant.sol | 94.59% (70/74) | 96.19% (101/105) | 100.00% (21/21) | 100.00% (3/3) |
| **Totals** | 87.50% (182/208) | 89.68% (226/252) | 96.42% (27/28) | 73.91% (17/23) |

## Miscellaneous
Employees of Panoptic and employees' family members are ineligible to participate in this audit.

Code4rena's rules cannot be overridden by the contents of this README. In case of doubt, please check with C4 staff.

