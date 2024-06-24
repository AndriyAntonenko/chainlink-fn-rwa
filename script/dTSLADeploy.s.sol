/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { NetworkConfig } from "./NetworkConfig.s.sol";

import { dTSLA } from "../src/dTSLA.sol";

contract dTSLADeploy is Script {
  function run() public {
    NetworkConfig networkConfig = new NetworkConfig();
    NetworkConfig.Config memory config = networkConfig.getNetworkConfig();

    vm.startBroadcast();
    deploy(
      config.functionsRouter,
      config.mintSourceCode,
      config.redeemSourceCode,
      config.subscriptionId,
      config.donId,
      config.tslaUsdPriceFeed,
      config.usdcUsdPriceFeed,
      config.reedemptionToken,
      config.donSecretsSlotId,
      config.donSecretsVersion
    );
    vm.stopBroadcast();
  }

  function deployFromNetworkConfig() public {
    NetworkConfig networkConfig = new NetworkConfig();
    NetworkConfig.Config memory config = networkConfig.getNetworkConfig();
    deploy(
      config.functionsRouter,
      config.mintSourceCode,
      config.redeemSourceCode,
      config.subscriptionId,
      config.donId,
      config.tslaUsdPriceFeed,
      config.usdcUsdPriceFeed,
      config.reedemptionToken,
      config.donSecretsSlotId,
      config.donSecretsVersion
    );
  }

  function deploy(
    address _functionsRouter,
    string memory _mintSourceCode,
    string memory _redeemSourceCode,
    uint64 _subscriptionId,
    bytes32 _donId,
    address _tslaUsdPriceFeed,
    address _usdcUsdPriceFeed,
    address _reedemptionToken,
    uint8 _donSecretsSlotId,
    uint64 _donSecretsVersion
  )
    public
    returns (dTSLA)
  {
    dTSLA dtsla = new dTSLA(
      _functionsRouter,
      _mintSourceCode,
      _redeemSourceCode,
      _subscriptionId,
      _donId,
      _tslaUsdPriceFeed,
      _usdcUsdPriceFeed,
      IERC20(_reedemptionToken),
      _donSecretsSlotId,
      _donSecretsVersion
    );
    return dtsla;
  }
}
