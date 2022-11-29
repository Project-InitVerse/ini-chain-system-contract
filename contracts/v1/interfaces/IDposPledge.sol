// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDposPledge {
    function state() external view returns (State);

    function totalVote() external view returns (uint256);

    function validator() external view returns (address);

    function switchState(bool pause) external;

    function punish() external;

    function removeValidatorIncoming() external;
}

enum State {
    Idle,
    Ready,
    Pause,
    Jail
}
