/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ConfirmedOwner } from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import { FunctionsClient } from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import { FunctionsRequest } from "@chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { OracleLib } from "./libraries/OracleLib.sol";

/// @title dTSLA
/// @author Andrii Antonenko
/// @notice Created by example from https://github.com/PatrickAlphaC/rwa-creator
contract dTSLA is ConfirmedOwner, FunctionsClient, ERC20 {
  error dTSLA__NotEnoughCollateral();
  error dTSLA__DoestNotMeetMinimalWithdrawalAmount();

  using FunctionsRequest for FunctionsRequest.Request;
  using Strings for uint256;

  enum dTslaRequestType {
    Mint,
    Redeem
  }

  struct dTslaRequest {
    dTslaRequestType requestType;
    uint256 amount;
    address requester;
  }

  uint256 private constant PRECISION = 10 ** 18;
  uint256 private constant PRICE_PRECISION = 10 ** 18;
  uint32 private constant FUNCTION_CALLBACK_GAS_LIMIT = 300_000;

  /// @dev Ex: if there is 200$ of TSLA in the brokerage, we can mint AT MOST 100$ of dTSLA
  uint256 private constant COLLATERAL_RATIO = 200; // 200%
  uint256 private constant COLLATERAL_PRECISION = 100;
  uint256 private constant MINIMAL_WITHDRAWAL_AMOUNT = 100e18;

  bytes32 private immutable i_donId;
  uint64 private immutable i_subscriptionId;
  address private immutable i_tslaUsdPriceFeed;
  address private immutable i_usdcUsdPriceFeed;
  IERC20 private immutable i_reedemptionToken;

  mapping(bytes32 requestId => dTslaRequest request) private s_requestIdToRequest;
  mapping(address user => uint256 pendingWithdrawalAmount) private s_usersToPendingWithdrawalAmounts;
  string private s_mintSourceCode;
  string private s_redeemSourceCode;
  uint256 private s_portfolioBalance;

  uint8 private s_secretsSlotId;
  uint64 private s_secretsVersion;

  constructor(
    address _functionsRouter,
    string memory _mintSourceCode,
    string memory _redeemSourceCode,
    uint64 _subscriptionId,
    bytes32 _donId,
    address _tslaUsdPriceFeed,
    address _usdcUsdPriceFeed,
    IERC20 _reedemptionToken,
    uint8 _secretsSlotId,
    uint64 _secretsVersion
  )
    ConfirmedOwner(msg.sender)
    FunctionsClient(_functionsRouter)
    ERC20("dTSLA", "dTSLA")
  {
    s_mintSourceCode = _mintSourceCode;
    s_redeemSourceCode = _redeemSourceCode;
    i_subscriptionId = _subscriptionId;
    i_donId = _donId;
    i_tslaUsdPriceFeed = _tslaUsdPriceFeed;
    i_usdcUsdPriceFeed = _usdcUsdPriceFeed;
    i_reedemptionToken = _reedemptionToken;
    s_secretsSlotId = _secretsSlotId;
    s_secretsVersion = _secretsVersion;
  }

  /// Send HTTP request to:
  /// 1. See how much TSLA is bought
  /// 2. If enough TSLA is in the alpaca account, mint dTSLA
  function sendMintRequest(uint256 _amount) external onlyOwner {
    FunctionsRequest.Request memory req;
    req.initializeRequestForInlineJavaScript(s_mintSourceCode);
    req.addDONHostedSecrets(s_secretsSlotId, s_secretsVersion);

    bytes32 requestId = _sendRequest(req.encodeCBOR(), i_subscriptionId, FUNCTION_CALLBACK_GAS_LIMIT, i_donId);
    s_requestIdToRequest[requestId] =
      dTslaRequest({ requestType: dTslaRequestType.Mint, amount: _amount, requester: msg.sender });
  }

  /// @notice User sends a request to sell TSLA for USDC (redemptionToken)
  /// This will have the chainlink function call our bank and do the following:
  /// 1. Sell TSLA on the brokerage
  /// 2. Buy USDC on the brokerage
  /// 3. Send USDC to this contract for the user to withdraw
  function sendRedeemRequest(uint256 _amountOfTsla) external {
    uint256 amountTslaInUsdc = getUsdcValueOfUsd(getUsdValueOfTsla(_amountOfTsla)); // 18 decimals
    if (amountTslaInUsdc < MINIMAL_WITHDRAWAL_AMOUNT) {
      revert dTSLA__DoestNotMeetMinimalWithdrawalAmount();
    }

    FunctionsRequest.Request memory req;
    req.initializeRequestForInlineJavaScript(s_redeemSourceCode);

    string[] memory args = new string[](2);
    args[0] = _amountOfTsla.toString();
    args[1] = amountTslaInUsdc.toString();
    req.setArgs(args);

    bytes32 requestId = _sendRequest(req.encodeCBOR(), i_subscriptionId, FUNCTION_CALLBACK_GAS_LIMIT, i_donId);

    s_requestIdToRequest[requestId] =
      dTslaRequest({ requestType: dTslaRequestType.Redeem, amount: _amountOfTsla, requester: msg.sender });

    _burn(msg.sender, _amountOfTsla);
  }

  /// Return the amount of TSLA  value (in USD) is stored in our broker
  /// If we have enough TSLA token, mint dTSLA
  function _mintFulfillRequest(bytes32 _requestId, bytes memory _response) internal {
    dTslaRequest memory req = s_requestIdToRequest[_requestId];

    uint256 amountOfTokensToMint = req.amount;
    s_portfolioBalance = uint256(bytes32(_response)); // amount of TSLA in the brokerage

    if (_getCollateralRatioAdjustedTotalBalance(amountOfTokensToMint) > s_portfolioBalance) {
      revert dTSLA__NotEnoughCollateral();
    }

    if (amountOfTokensToMint != 0) {
      _mint(req.requester, amountOfTokensToMint);
    }
  }

  function _redeemFulfillRequest(bytes32 _requestId, bytes memory _response, bytes memory _err) internal {
    dTslaRequest memory req = s_requestIdToRequest[_requestId];
    if (_err.length != 0) {
      _mint(req.requester, req.amount); // return dTSLA to the user
    }

    uint256 withdrawalAmount = uint256(bytes32(_response));
    if (withdrawalAmount == 0) {
      _mint(req.requester, req.amount); // return dTSLA to the user
    }

    s_usersToPendingWithdrawalAmounts[req.requester] += withdrawalAmount;
  }

  function withdraw() external {
    uint256 amount = s_usersToPendingWithdrawalAmounts[msg.sender];
    s_usersToPendingWithdrawalAmounts[msg.sender] = 0;
    SafeERC20.safeTransfer(i_reedemptionToken, msg.sender, amount);
  }

  /// @notice Calculate the amount of required collateral to mint dTSLA
  function _getCollateralRatioAdjustedTotalBalance(uint256 amountOfTokensToMint) internal view returns (uint256) {
    uint256 newTotalValue = _getCalculatedNewTotalValue(amountOfTokensToMint);
    return newTotalValue * COLLATERAL_RATIO / COLLATERAL_PRECISION;
  }

  function _getCalculatedNewTotalValue(uint256 _addedNumberOfTokens) internal view returns (uint256) {
    return (totalSupply() + _addedNumberOfTokens) * getTslaPrice() / PRECISION;
  }

  function getTslaPrice() public view returns (uint256) {
    AggregatorV3Interface chainlinkFeed = AggregatorV3Interface(i_tslaUsdPriceFeed);
    uint256 dec = chainlinkFeed.decimals();
    (, int256 price,,,) = OracleLib.staleCheckLatestRoundData(chainlinkFeed);
    // to precision
    return uint256(price) * PRICE_PRECISION / 10 ** dec;
  }

  function getUsdcPrice() public view returns (uint256) {
    AggregatorV3Interface chainlinkFeed = AggregatorV3Interface(i_usdcUsdPriceFeed);
    uint256 dec = chainlinkFeed.decimals();
    (, int256 price,,,) = OracleLib.staleCheckLatestRoundData(chainlinkFeed);
    // to precision
    return uint256(price) * PRICE_PRECISION / 10 ** dec;
  }

  /// @param _tslaAmount Amount in TSLA (0 decimals)
  /// @return Amount in USD (18 decimals)
  function getUsdValueOfTsla(uint256 _tslaAmount) public view returns (uint256) {
    return _tslaAmount * getTslaPrice();
  }

  /// @param _usdAmount Amount in USD (18 decimals)
  /// @return Amount in USDC (18 decimals)
  function getUsdcValueOfUsd(uint256 _usdAmount) public view returns (uint256) {
    return _usdAmount * PRECISION / getUsdcPrice();
  }

  /// @inheritdoc FunctionsClient
  function fulfillRequest(
    bytes32 _requestId,
    bytes memory _response,
    bytes memory _err
  )
    internal
    override(FunctionsClient)
  {
    dTslaRequestType requestType = s_requestIdToRequest[_requestId].requestType;
    if (requestType == dTslaRequestType.Mint) {
      _mintFulfillRequest(_requestId, _response);
    } else {
      _redeemFulfillRequest(_requestId, _response, _err);
    }
  }

  /*//////////////////////////////////////////////////////////////
                              SETTERS
  //////////////////////////////////////////////////////////////*/
  function setSecretsSlotId(uint8 _newSecretSlotId) external onlyOwner {
    s_secretsSlotId = _newSecretSlotId;
  }

  function setSecretsVersion(uint64 _newSecretsVersion) external onlyOwner {
    s_secretsVersion = _newSecretsVersion;
  }

  /*//////////////////////////////////////////////////////////////
                          VIEW AND PURE
  //////////////////////////////////////////////////////////////*/

  function getRequest(bytes32 _requestId) external view returns (dTslaRequest memory) {
    return s_requestIdToRequest[_requestId];
  }

  function getPendingWithdrawalAmount(address _user) external view returns (uint256) {
    return s_usersToPendingWithdrawalAmounts[_user];
  }

  function getMintSourceCode() external view returns (string memory) {
    return s_mintSourceCode;
  }

  function getRedeemSourceCode() external view returns (string memory) {
    return s_redeemSourceCode;
  }
}
