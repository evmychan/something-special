# Submitting your GenTx for the Evmos Mainnet

Thank you for becoming a genesis validator on Evmos! This guide will provide instructions on setting up a node, submitting a gentx, and other tasks needed to participate in the launch of the Evmos Mainnet.

A `gentx` does three things:

- Registers the validator account you created as a validator operator account (i.e. the account that controls the validator).
- Self-delegates the provided amount of staking tokens.
- Links the operator account with a Tendermint node pubkey that will be used for signing blocks. If no `--pubkey` flag is provided, it defaults to the local node pubkey created via the `evmosd init` command.

## Setup

Software:

- Go version: [v1.17+](https://golang.org/dl/)
- Evmos version: [v1.0.0-beta1](https://github.com/tharsis/evmos/releases)

To verify that Go is installed:

```sh
go version
# Should return go version go1.17 linux/amd64
```

## Instructions (Launch: `2022-02-28T18:00:00Z`)

These instructions are written targeting an Ubuntu 20.04 system. Relevant changes to commands should be made depending on the OS/architecture you are running on.

1. Install `evmosd`

   ```bash
   git clone https://github.com/tharsis/evmos
   cd evmos && git checkout tags/v1.0.0-beta1
   make install
   ```

   Make sure to checkout to the [`v1.0.0-beta1`](https://github.com/tharsis/evmos/releases) tag.

   Verify that everything is OK. If you get something *like* the following, you've successfully installed Evmos on your system.

   ```sh
   evmosd version --long

   name: evmos
   server_name: evmosd
   version: v1.0.0-beta1
   commit: e7c88a678aee545ac903e29dc48dab5409c95a3e
   build_tags: netgo,ledger
   go: go version go1.17 darwin/amd64
   ```

2. Initialize the `evmosd` directories and create the local file with the correct chain-id

   ```bash
   evmosd init <moniker> --chain-id=evmos_9001-1
   ```

3. You should have already created a key pair

4. Add the account to your local genesis file with a given amount and key you just created.

   ```bash
   evmosd add-genesis-account $(evmosd keys show <your key name> -a) <correct balance in genesis file>aevmos
   ```

   Make sure to use `aevmos` denom, not `evmos`.

5. Create the gentx

   ```bash
   evmosd gentx <your key name> <correct balance in genesis file>aevmos \
     --chain-id=evmos_9001-1 \
     --moniker=<moniker> \
     --details="My moniker description" \
     --commission-rate=0.05 \
     --commission-max-rate=0.2 \
     --commission-max-change-rate=0.01 \
     --pubkey $(evmosd tendermint show-validator) \
     --identity="<Keybase.io GPG Public Key>"
   ```
   
   Any gentxs with a commission rate set below 5% will be removed from the set.

6. Create Pull Request to this repository ([evmychan/something-special](https://github.com/evmychan/something-special/)) with the file  `gentxs/<your validator moniker>.json`. In order to be a valid submission, you need the .json file extension and no whitespace or special characters in your filename. Your PR should be one addition.
