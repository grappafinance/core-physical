// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import "../config/types.sol";
import "../config/constants.sol";

/**
 * @title MoneynessLib
 * @dev Library to calculate the moneyness of options
 */
library MoneynessLib {
    using FixedPointMathLib for uint256;

    /**
     * @notice   get the cash value of a call option strike
     * @dev      returns max(spot - strike, 0)
     * @param spot  spot price in usd term with 6 decimals
     * @param strike strike price in usd term with 6 decimals
     *
     */
    function getCallCashValue(uint256 spot, uint256 strike) internal pure returns (uint256) {
        unchecked {
            return spot < strike ? 0 : spot - strike;
        }
    }

    /**
     * @notice   get the cash value of a put option strike
     * @dev      returns max(strike - spot, 0)
     * @param spot spot price in usd term with 6 decimals
     * @param strike strike price in usd term with 6 decimals
     *
     */
    function getPutCashValue(uint256 spot, uint256 strike) internal pure returns (uint256) {
        unchecked {
            return spot > strike ? 0 : strike - spot;
        }
    }
}
