// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDposPledge {
    function state() external view returns (State);

    function totalVote() external view returns (uint256);

    function validator() external view returns (address);

    function switchState(bool pause) external;

    function punish() external;

    function removeValidatorIncoming() external;

    function getPendingReward(address _voter) external view returns (uint256);

    function getVoterInfo(address _user) external view returns (VoterInfo memory);
}
    struct VoterInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 withdrawPendingAmount;
        uint256 withdrawExitBlock;
    }

    enum State {
        Idle,
        Ready,
        Pause,
        Jail
    }
