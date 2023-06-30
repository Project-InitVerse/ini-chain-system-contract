// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./interface/IValFactory.sol";
contract Mockown {
    address public owner;
    address public factory;
    function setfactory(address a) external{
        factory = a;
    }
    function setOwner(address a) external{
        owner = a;
    }
    function mockAttack() external{
        IValFactory(factory).exitProduceBlock();
    }
}
