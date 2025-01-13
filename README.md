# contracts

Write validators in the `validators` folder, and supporting functions in the `lib` folder using `.ak` as a file extension.

```aiken
validator my_first_validator {
  spend(_datum: Option<Data>, _redeemer: Data, _output_reference: Data, _context: Data) {
    True
  }
}
```

## Building

```sh
aiken build
```

## Configuring

**aiken.toml**
```toml
[config.default]
network_id = 41
```

Or, alternatively, write conditional environment modules under `env`.

## Testing

You can write tests in any module using the `test` keyword. For example:

```aiken
use config

test foo() {
  config.network_id + 1 == 42
}
```

To run all tests, simply do:

```sh
aiken check
```

To run only tests matching the string `foo`, do:

```sh
aiken check -m foo
```

## Documentation

If you're writing a library, you might want to generate an HTML documentation for it.

Use:

```sh
aiken docs
```

## Resources

Find more on the [Aiken's user manual](https://aiken-lang.org).


---
created: '"2024-12-10T18:36"'
tags:
  - "#cardano"
  - "#contracts"
links:
---
***

# Smart contracts design for carbon registries

## Overview

This repo is the smart contract repository that allows the tokenization of carbon credit projects in early stages as well as tokenization of certified carbon credits. 

## Example use case

Project X is a hypothetical project that has undergone initial validation phases conducted by consultants. These consultants evaluate the project from technical and financial perspectives. The result is an estimation of the retention capacity or CO2eq captured over multiple periods, with a horizon of up to 20 years. Every five years, a validation is conducted to confirm the quantity effectively retained. This value is then compared to the initial estimate to identify potential biases.

From the technical and financial analysis conducted during the pre-feasibility phase, the project is estimated to emit the following quantities of carbon credits:

| Period                    | Period 1 | Period 2 | Period 3 | Period 4 |
| ------------------------- | -------- | -------- | -------- | -------- |
| Retention CO2Eq           | 107.455  | 172.949  | 238.043  | 290.991  |
| % of ceritified tokens    | 13,28%   | 21,37%   | 29,41%   | 35,95%   |
| Overall CO2eq accumulated | 107.455  | 280.404  | 518.447  | 809.438  |

From an initial estimation of 809,438 tonnes of CO2eq, the issuance of carbon credit certificates is divided into four periods, as shown in the table above.

This amount of tokens is also distributed to different smart contracts based on financial estimations as follows:

| Initial distribution | # Tokens | Percentage |
| -------------------- | -------- | ---------- |
| Investors            | 272.000  | 33,60%     |
| Administrators       | 100.000  | 12,35%     |
| Community            | 13.000   | 1,61%      |
| Owners               | 107.000  | 13,22%     |
| BioC                 | 110.043  | 13,59%     |
| Buffer               | 207.395  | 25,62%     |
|                      | 809.438  | 100,00%    |

These tokens are known as "grey tokens," as they represent an early investment in a project that has not yet achieved the certification milestone.

Investors can then access the marketplace to buy, sell, or transfer tokens directly by interacting with the Investors' Smart Contract or via the P2P market. Tokens are sent to users' wallets, where they represent a fraction of ownership or participation in the project as early investors. The initial token price is determined through a financial analysis conducted by consultants, who assess the project's feasibility, execution costs, and ROI for stakeholders. The funds generated from the sales process are used to ensure the project's execution, increasing the likelihood of achieving certification.

## Token description

The application utilizes both NFT and FT tokens.

### NFT tokens
NFT tokens are primarily used to identify the UTXOs associated with the application, allowing for the retrieval of sensitive information stored in datums, particularly in core wallet and contract addresses.

### FT tokens

As briefly mentioned earlier, the application employs two types of FT tokens: grey and green.

- Grey Tokens: These tokens represent a percentage of participation in the project. They are a future promise of carbon credits to be certified if the project is successful. These tokens are minted at a ratio of 1 token per tonne of CO2eq, with a fixed total supply corresponding to the initial estimation. The estimation accounts for uncertainty, which is represented by a "buffer quantity" to provide flexibility during the certification process and maintain the balance of carbon credits once confirmed.

- Green Tokens: These tokens represent 1 tonne of CO2eq certified by a certification entity. The certification entity issues a certificate that is stored in the system and tokenized in a 1:1 ratio with the certified carbon credits.

## List of main Contracts and the Architecture

### Protocol type contracts

- **Protocol contracts**: Manage protocol parameters for easy on-chain access and detailed project information.
- **Main protocol**: Contains information in one UTXO, such as AdminWallet, OracleId, and the percentage commission allocated to beneficiaries during token purchases.
- **Project protocol**: Contains project details in a datum, including project ID, description, NFT project identifier, project state (initialized, distributed, certified, closed), and emission dates. Unique addresses are generated for each project.
- **Oracle protocol**: Contains one UTXO per project with an NFT for project identification. The datum includes token prices in ADA, USD, and COP, which are updated periodically (e.g., daily).

### Mint type contracts

- **NFTs mint contract**: A native script used to create NFT tokens for identifying UTXOs across the application (e.g., oracle NFT, protocol NFT, etc.).
- **Grey mint contract**: Controls the minting and burning of grey tokens on a project basis.  
- **Green mint contract**: Controls the minting and burning of green tokens on a project basis.

### Spend type contracts

- **Investor contract**: Manages the purchase and sale of grey tokens in the marketplace.

	- Datum Info:
		- Beneficiary: Specifies the recipient who will receive a fraction of the price paid for the tokens.
	- Reference Info
		- Oracle: Provides the token price.
	- Redeemer Actions:
      - Buy: Allows users to purchase tokens.
      - Unlist: Enables users to remove tokens from the contract without completing a purchase.
  - Validation
    - Buy action:
      - Ensures the price paid is accurate.
      - Confirms that the commission is correctly sent to the beneficiary.
  - Unlist Action:
    - Requires the transaction to be signed by the beneficiary.

> [!Considerations]
> 	How to overcome the cuncurrency issue of 1 utxo or few utxos holding the majority of the tokens.
> 	

- **Owner contract**: Manages the tokens distributed to the landowners associated with the project. It acts as a vesting contract, where only beneficiaries can redeem the tokens after a specified time.

	- Datum info:
      - List of owners: Public key hashes (PKH) of the owners who are part of the group entitled to claim tokens in specified amounts.
      - After-epoch claim: Specifies the epoch after which claims can be made.
      - Core wallet: The designated wallet managing the contract.

	- Reference Info:
		- None

	- Redeemer Actions:
		- Claim: Enables beneficiaries to claim their allocated tokens.
		- Unlist: Allows the removal of tokens from the contract without an actual purchase.

	- Validations:
		- Claim Action:
			- Claim is only valid after the specified date and time.
			- The owner listed must sign the transaction.
			- The claimed amount cannot exceed the specified limit for the owner.
			- Tokens must be sent to the owner's address.
		- Unlist Action:
			- Must be signed by the core wallet.


- **Buffer contract**: Manages the tokens accounting for uncertainty in the initial estimation of the overall carbon retention of the project. As the project progresses, the confirmed amounts of carbon credits may differ from the initial estimates. The Buffer Contract allows for burning or redistributing the held tokens to maintain the overall balance.

	- Datum info:
		- List of owners: PKHs of the owners entitled to claim tokens in specified amounts.
		- After-epoch claim: Specifies the epoch after which claims can be made.
		- Core wallet: The designated wallet managing the contract.

  - Reference Info:
    - None

  - Redeemer Actions:
	  - Claim: Enables beneficiaries to claim their allocated tokens.
    - Unlist: Allows the removal of tokens from the contract without an actual purchase.

  - Validations:
    - Claim Actions:
      - Claim is only valid after the specified date and time.
      - The owner listed must sign the transaction.
      - The claimed amount cannot exceed the specified limit for the owner.
      - Tokens must be sent to the owner's address.

  - Unlist Action:
    - Must be signed by the core wallet.

- **Community contract**: This contract holds tokens to incentivize work or initiatives from the community involved in the project. Community members are compensated with predefined amounts of tokens upon achieving clear outcomes. For example, consultants who conduct the initial feasibility study of the project and estimate its carbon credits are compensated proportionally with tokens held in this contract.

- **Green contract**: Manages the green tokens that represent actual carbon credits. The contract supports actions such as listing (minting) in the marketplace, delisting (burning), buying, selling, and compensating (burning).
