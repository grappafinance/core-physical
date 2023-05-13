// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// for easier import
import "../core/engines/cross-margin/errors.sol";

/* ------------------------ *
 *      Shared Errors       *
 * -----------------------  */

error NoAccess();

/* ------------------------ *
 *      Pomace Errors       *
 * -----------------------  */

/// @dev asset already registered
error PM_AssetAlreadyRegistered();

/// @dev margin engine already registered
error PM_EngineAlreadyRegistered();

/// @dev amounts length specified to batch settle doesn't match with tokenIds
error PM_WrongArgumentLength();

/// @dev cannot settle an unexpired option
error PM_NotExpired();

/// @dev settlement price is not finalized yet
error PM_PriceNotFinalized();

/// @dev cannot mint token after expiry
error PM_InvalidExpiry();

/// @dev cannot mint token with zero settlement window
error PM_InvalidSettlementWindow();

/// @dev burn or mint can only be called by corresponding engine.
error PM_Not_Authorized_Engine();

/* ---------------------------- *
 *   Common BaseEngine Errors   *
 * ---------------------------  */

/// @dev can only merge subaccount with put or call.
error BM_CannotMergeSpread();

/// @dev only spread position can be split
error BM_CanOnlySplitSpread();

/// @dev type of existing short token doesn't match the incoming token
error BM_MergeTypeMismatch();

/// @dev product type of existing short token doesn't match the incoming token
error BM_MergeProductMismatch();

/// @dev expiry of existing short token doesn't match the incoming token
error BM_MergeExpiryMismatch();

/// @dev cannot merge type with the same strike. (should use burn instead)
error BM_MergeWithSameStrike();

/// @dev account is not healthy / account is underwater
error BM_AccountUnderwater();

/// @dev msg.sender is not authorized to ask margin account to pull token from {from} address
error BM_InvalidFromAddress();
