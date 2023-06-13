// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract MockProviderFactory {
    function getProviderInfoLength() external view returns(uint256){
        return 5;
    }
    function whetherCanPOR(address) external view returns(bool){
        return true;
    }
    function changeProviderState(address,bool) external {

    }
}
