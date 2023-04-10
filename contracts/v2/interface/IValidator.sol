// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

    enum ValidatorState{
        Prepare,
        Watch,
        Punish,
        Ready,
        Exit
    }
interface IValidator {
    function pledge_amount() external view returns(uint256);
    function addMargin() external payable;
    function punish()external ;
    function isProduceBlock() external view returns(bool);
    function state() external view returns(ValidatorState);
    function create_time() external view returns(uint256);
    function changeValidatorState(ValidatorState _state) external;
}
