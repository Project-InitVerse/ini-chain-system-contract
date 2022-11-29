// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IDposFactory.sol";
import "./interfaces/IPunish.sol";

contract Params {
    bool public initialized;

    // System contracts
    IDposFactory public constant validatorsContract = IDposFactory(0x000000000000000000000000000000000000c002);
    IPunish public constant punishContract = IPunish(0x000000000000000000000000000000000000C003);

    //TODO : for test
    /*
    IDposFactory
    public validatorsContract;
    IPunish
    public punishContract;
    function setAddress(address _val, address _punish)
    external {
        validatorsContract = IDposFactory(_val);
        punishContract = IPunish(_punish);
    }*/
    // System params
    uint16 public constant MaxValidators = 15;

    //TODO : for test
    /*
    uint256 public constant PosMinMargin = 5 ether;
    uint public constant PunishAmount = 1 ether;

    uint constant PERCENT_BASE = 10000;

    uint public constant JailPeriod = 0;
    uint public constant MarginLockPeriod = 0;
    uint public constant WithdrawLockPeriod = 0;
    uint public constant PercentChangeLockPeriod = 0;*/
    uint256 public constant PosMinMargin = 5000 ether;
    uint256 public constant PunishAmount = 100 ether;

    uint256 public constant JailPeriod = 86400;
    uint256 public constant MarginLockPeriod = 403200;
    uint256 public constant WithdrawLockPeriod = 86400;
    uint256 public constant PercentChangeLockPeriod = 86400;
    uint256 constant PERCENT_BASE = 10000;

    modifier onlyMiner() {
        require(msg.sender == block.coinbase, "Miner only");
        _;
    }

    modifier onlyNotInitialized() {
        require(!initialized, "Already initialized");
        _;
    }

    modifier onlyInitialized() {
        require(initialized, "Not init yet");
        _;
    }

    modifier onlyPunishContract() {
        require(msg.sender == address(punishContract), "Punish contract only");
        _;
    }

    modifier onlyBlockEpoch(uint256 epoch) {
        require(block.number % epoch == 0, "Block epoch only");
        _;
    }

    modifier onlyValidatorsContract() {
        require(msg.sender == address(validatorsContract), "Validators contract only");
        _;
    }

    modifier onlyValidAddress(address _address) {
        require(_address != address(0), "Invalid address");
        _;
    }
}
