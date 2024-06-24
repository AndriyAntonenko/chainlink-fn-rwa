// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title USDCPlaceholder
/// @notice This is a simple ERC20 contract for USDC, we will use it as a placeholder for the real USDC token
contract USDCPlaceholder is ERC20 {
  uint256 constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18;

  constructor() ERC20("USDC", "USDC") {
    _mint(msg.sender, INITIAL_SUPPLY);
  }

  function mint(address account, uint256 amount) external {
    _mint(account, amount);
  }
}
