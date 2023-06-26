// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./interface/IPunishContract.sol";
import "./interface/IValFactory.sol";

contract PunishContract is IPunishContract {
    mapping(uint256 => PunishItem) public index_punish_items;
    mapping(address => PunishItem[]) public validator_punish_items;
    // TODO for formal
    IValFactory public constant factory_address = IValFactory(0x000000000000000000000000000000000000c002);
    // TODO for test
    //IValFactory public factory_address;
    uint256 public current_index = 0;
    constructor(){
        //current_index = 0;
    }
    function newPunishItem(address owner, uint256 punish_amount, uint256 balance_left) external override {
        if(factory_address.getValidator(owner) != msg.sender){
            return;
        }
        PunishItem memory new_data;
        new_data.punish_owner = owner;
        new_data.punish_amount = punish_amount;
        new_data.balance_left = balance_left;
        new_data.block_number = block.number;
        new_data.block_timestamp = block.timestamp;
        index_punish_items[current_index] = new_data;
        validator_punish_items[owner].push(new_data);
        current_index = current_index + 1;
    }
    function getValidatorPunishLength(address val)external view returns(uint256){
        return validator_punish_items[val].length;
    }
    //TODO for test
//        function setFactoryAddr(address fac_addr) external {
//            factory_address = IValFactory(fac_addr);
//        }
}
