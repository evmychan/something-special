#!/bin/bash
EVMOS_HOME="/tmp/evmosd$(date +%s)"
RANDOM_KEY="randomevmosvalidatorkey"
MAXBOND="15901060070671400000" # 15.90106 EVMOS
GENACC_BALANCE="17000000000000000000" # 17 EVMOS

# NOTE: This script is designed to run in CI.

print() {
    echo "$1" | boxes -d stone
}

set -e
echo "Cloning the Evmos repo and building $BINARY_VERSION"

rm -rf evmos
git clone "$GH_URL" > /dev/null 2>&1
cd evmos
git checkout tags/"$BINARY_VERSION" > /dev/null 2>&1
make build > /dev/null 2>&1
chmod +x "$DAEMON"
# Get the diff between main and commit
echo "Diff is on $GENTX_FILE"
LEN_GENTX=${#GENTX_FILE}

if [ $LEN_GENTX -eq 0 ]; then
    echo "No new gentx file found."
else
    # TODO: Check if white space in name
    GENACC=$(jq -r '.body.messages[0].delegator_address' "$GENTX_FILE")
    denomquery=$(jq -r '.body.messages[0].value.denom' "$GENTX_FILE")
    amountquery=$(jq -r '.body.messages[0].value.amount' "$GENTX_FILE")

function amount {
   AMOUNT="$amountquery" MAXAMOUNT="$MAXBOND" python - <<END
   import os
   amount = int(os.environ['AMOUNT'])
   maxamount = int(os.environ['MAXAMOUNT'])
   print( amount > maxamount)
END
}

    # only allow $DENOM tokens to be bonded
    if [ "$denomquery" != $DENOM ]; then
        echo "incorrect denomination on $GENTX_FILE" | tee -a bad_gentxs.out
        exit 1
    fi

    # limit the amount that can be bonded
    if [ $(echo $(amount)) == 'true' ]; then
        echo "Error bonded too much, your amount is $amountquery" | tee -a bad_gentxs.out
        exit 1
    fi

    # Adding random validator key so that we can start the network ourselves
    $DAEMON keys add $RANDOM_KEY --keyring-backend test --home "$EVMOS_HOME" > /dev/null 2>&1
    $DAEMON init --chain-id $CHAIN_ID validator --home "$EVMOS_HOME" > /dev/null 2>&1

    # Setting the genesis time earlier so that we can start the network in our test
    sed -i '/genesis_time/c\   \"genesis_time\" : \"2021-03-29T00:00:00Z\",' "$EVMOS_HOME"/config/genesis.json
    # Update the various denoms in the genesis
    jq -r --arg DENOM "$DENOM" '(..|objects|select(has("denom"))).denom |= $DENOM | .app_state.staking.params.bond_denom = $DENOM | .app_state.mint.params.mint_denom = $DENOM' "$EVMOS_HOME"/config/genesis.json | sponge "$EVMOS_HOME"/config/genesis.json

    # Add genesis accounts
    $DAEMON add-genesis-account "$GENACC" $GENACC_BALANCE$DENOM --home "$EVMOS_HOME"
    $DAEMON add-genesis-account $RANDOM_KEY $GENACC_BALANCE$DENOM --home "$EVMOS_HOME" \
        --keyring-backend test

    $DAEMON gentx $RANDOM_KEY $MAXBOND$DENOM --home "$EVMOS_HOME" \
        --keyring-backend test --chain-id $CHAIN_ID

    cp "$GENTX_FILE" "$EVMOS_HOME"/config/gentx/
    $DAEMON collect-gentxs --home "$EVMOS_HOME"

    sed -i '/persistent_peers =/c\persistent_peers = ""' "$EVMOS_HOME"/config/config.toml
    echo "Run validate-genesis on created genesis file"
    $DAEMON validate-genesis --home "$EVMOS_HOME"

    echo "Starting the node to get complete validation (module params, signatures, etc.)"
    $DAEMON start --home "$EVMOS_HOME" &

    sleep 10s

    echo "Checking the status of the network"
    $DAEMON status --node http://localhost:26657

    echo "Killing the daemon"
    pkill evmosd > /dev/null 2>&1

    echo "Cleaning the files"
    rm -rf "$EVMOS_HOME" >/dev/null 2>&1
fi

echo "Done."
