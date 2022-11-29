// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IDposPledge.sol";

interface IDposFactory {
    function improveRanking() external;

    function lowerRanking() external;

    function removeRanking() external;

    function pendingReward(IDposPledge pool) external view returns (uint256);

    function withdrawReward() external;

    function dposPledges(address validator) external view returns (IDposPledge);
}

enum Operation {
    Distribute,
    UpdateValidators
}
