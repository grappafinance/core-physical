#!/usr/bin/env bash

if [ -f .env ]
then
  export $(cat .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

echo "Please enter the chain id..."
read chain_id

echo ""

echo "Please enter the deployed OptionToken address..."
read optionToken


echo ""

echo "Verifying OptionToken contract on Etherscan..."

forge verify-contract \
  $optionToken \
  ./src/core/OptionToken.sol:OptionToken \
  --etherscan-api-key ${ETHERSCAN_API_KEY} \
  --chain-id $chain_id \
  --compiler-version 0.8.17+commit.8df45f5f \
  --num-of-optimizations 100000 \
  --constructor-args-path script/core/optionToken/constructor-args.txt \
  --watch