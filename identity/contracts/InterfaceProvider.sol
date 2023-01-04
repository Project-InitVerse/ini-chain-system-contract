// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IProviderFactory{

    // @notice Returns provider contract address if account is a provider else return 0x0
    function getProvideContract(address account) external view returns(address);
    // @notice Returns provider contract available resources
    function getProvideResource(address account) external view returns(uint256,uint256,uint256);
    // @notice Returns provider contract total resources
    function getProvideTotalResource(address account) external view returns(uint256,uint256,uint256);
    // @notice Provide notify factory change total resources
    function changeProviderResource(uint256 cpu_count, uint256 mem_count, uint256 storage_count, bool add) external;
    // @notice Provide notify factory change used resources
    function changeProviderUsedResource(uint256 cpu_count, uint256 mem_count, uint256 storage_count, bool add) external;
    // @notice Order use to consume provider resource
    function consumeResource(address account,uint256 cpu_count, uint256 mem_count, uint256 storage_count)external;
    // @notice Order use to recover provider resource
    function recoverResource(address account,uint256 cpu_count, uint256 mem_count, uint256 storage_count)external;
}
interface IProvider{
    function getLeftResource() external view returns(uint256,uint256,uint256);
    function getTotalResource() external view returns(uint256,uint256,uint256);
    function consumeResource(uint256 ,uint256 ,uint256 ) external;
    function recoverResource(uint256, uint256, uint256) external;
    function owner() external view returns(address);
    function info() external view returns(string memory);
    function changeActive(bool active) external;
    function isActive()external view returns(bool);
}
