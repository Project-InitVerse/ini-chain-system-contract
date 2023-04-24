// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IValFactory {
    function validator_pledgeAmount() external view returns(uint256);
    function getPunishAmount() external view returns(uint256);
    function punish_address() external view returns(address);
    function removeRankingList() external ;
    function exitProduceBlock() external;
    function validator_lock_time() external view returns(uint256);
    function validator_punish_interval() external view returns(uint256);
    function validator_punish_start_limit() external view returns(uint256);
}
