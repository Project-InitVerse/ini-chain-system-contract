// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
interface IProviderFactory{
    function getProviderInfoLength() external view returns(uint256);
    function whetherCanPOR(address) external view returns(bool);
    function changeProviderState(address,bool) external;
    function removePunishList(address provider) external;
    function tryPunish(address new_provider) external;
}
