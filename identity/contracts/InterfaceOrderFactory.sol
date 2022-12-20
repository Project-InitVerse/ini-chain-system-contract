// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
struct Order{
    address owner;
    uint256 v_cpu;
    uint256 v_memory;
    uint256 v_storage;
    string cert_key;
    string trx_id;
    uint8 state;
    uint256 endtime;
}

interface IOrderFactory{

    // @notice Returns provider contract address if account is a provider else return 0x0
    //    function reduceResource(uint256 _cpu,uint256 _memory,uint256 _storage) external;
    /*
    function get_minimum_deposit_amount() external view  returns (uint256);
    function change_order_stats(uint256 state)  external;
    function max_quote_time() external view;
    function getOrder(uint256 orderId) external view returns(Order memory);
*/
    function checkIsOrder(address orderAddress) external view returns(uint256);
}
