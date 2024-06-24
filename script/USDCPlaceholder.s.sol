/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";

import { USDCPlaceholder } from "../src/placeholders/USDCPlaceholder.sol";

contract USDCPlaceholderDeploy is Script {
  function run() public {
    vm.startBroadcast();
    new USDCPlaceholder();
    vm.stopBroadcast();
  }
}
