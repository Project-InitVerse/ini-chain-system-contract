// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IValFactory {
    function validator_pledgeAmount() external view returns(uint256);
    function getPunishAmount() external view returns(uint256);
    function punish_address() external view returns(address);
    function removeRankingList() external ;
    function exitProduceBlock() external;
}
