/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";

contract NetworkConfig is Script {
  string constant ALPACA_MINT_SOURCE_CODE_LOCATION = "./functions/sources/alpaca-balance.js";
  string constant ALPACA_REDEEM_SOURCE_CODE_LOCATION = "";

  struct Config {
    address functionsRouter;
    string mintSourceCode;
    string redeemSourceCode;
    bytes32 donId;
    uint64 subscriptionId;
    address tslaUsdPriceFeed;
    address usdcUsdPriceFeed;
    address reedemptionToken;
    uint8 donSecretsSlotId;
    uint64 donSecretsVersion;
  }

  function getNetworkConfig() public view returns (Config memory) {
    return getSepoliaConfig();
  }

  function getSepoliaConfig() private view returns (Config memory) {
    string memory mintSourceCode = vm.readFile(ALPACA_MINT_SOURCE_CODE_LOCATION);

    // This is not magic values, this is an actual config for the Sepolia network
    return Config({
      functionsRouter: 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0,
      mintSourceCode: mintSourceCode,
      redeemSourceCode: "",
      subscriptionId: 3119,
      donId: hex"66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000",
      tslaUsdPriceFeed: 0xc59E3633BAAC79493d908e63626716e204A45EdF, // On the Sepolia network we will use LINK/USD feed
      usdcUsdPriceFeed: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E, // Custom ERC20 token
      reedemptionToken: 0x5901b214Ecc9d917E4a507d055c353D50d4e569c,
      donSecretsSlotId: 0,
      donSecretsVersion: 1_719_232_147
    });
  }
}
