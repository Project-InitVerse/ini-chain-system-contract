// SPDX-License-Identifier: MIT
/*
pragma solidity ^0.8.0;

import "";

contract PosPledge is Ownable {
    mapping(uint256 => uint256) public index;
    //mapping(uint256=>uint256) public pos_to_index;
    uint256 public index_length = 0;
    uint256 public current_end = 0;
    mapping(uint256 => currencyAge) pos_pledges;
    struct currencyAge {
        uint256 amount;
        uint256 pledge_time;
        bool redeemed;
    }

    receive() external payable {
        require(msg.sender == owner());
        require(msg.value > 0, "PosPledge:pledge amount must over zero");
        pos_pledges[current_end] = currencyAge({ amount: msg.value, pledge_time: block.timestamp, redeemed: false });
        //pos_to_index[current_end] = index_length;
        index[index_length] = current_end;
        current_end = current_end + 1;
        index_length = index_length + 1;
    }

    function pledgeToken() public payable onlyOwner {
        require(msg.value > 0, "PosPledge:pledge amount must over zero");
        pos_pledges[current_end] = currencyAge({ amount: msg.value, pledge_time: block.timestamp, redeemed: false });
        index[index_length] = current_end;
        current_end = current_end + 1;
        index_length = index_length + 1;
    }

    function redeemToken(uint256 _index) public onlyOwner {
        require(_index < index_length);
        uint256 pos_index = index[_index];
        require(pos_pledges[pos_index].redeemed == false);
        pos_pledges[pos_index].redeemed = true;
        if (_index != index_length - 1) {
            index[_index] = index[index_length - 1];
        }
        index_length = index_length - 1;
    }
}

contract PosFactory is Ownable {
    mapping(address => address) public poser_contract;
    event PosPledgeCreate(address indexed poser, address indexed pos_contract);

    function createPosPledge() public {
        require(poser_contract[msg.sender] == address(0), "PosFactory: this account has create pos pledge contract");
        require(msg.sender == address(0), "PosFactory:Invalid address");
        bytes32 salt = keccak256(abi.encodePacked(msg.sender));
        PosPledge pos_pledge = new PosPledge{ salt: salt }();
        pos_pledge.transferOwnership(msg.sender);
        poser_contract[msg.sender] = address(pos_pledge);
        emit PosPledgeCreate(msg.sender, address(pos_pledge));
    }
}
*/
