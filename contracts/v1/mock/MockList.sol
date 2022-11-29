// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IDposPledge.sol";
import "../library/SortedList.sol";

contract MockList {
    using SortedLinkedList for SortedLinkedList.List;

    SortedLinkedList.List public list;

    function improveRanking(IDposPledge _value) external {
        list.improveRanking(_value);
    }

    function lowerRanking(IDposPledge _value) external {
        list.lowerRanking(_value);
    }

    function removeRanking(IDposPledge _value) external {
        list.removeRanking(_value);
    }

    function prev(IDposPledge _value) view external returns(IDposPledge){
        return list.prev[_value];
    }

    function next(IDposPledge _value) view external returns(IDposPledge){
        return list.next[_value];
    }

    function clear() external {
        IDposPledge _tail = list.tail;

        while(_tail != IDposPledge(address(0))) {
            IDposPledge _prev = list.prev[_tail];
            list.removeRanking(_tail);
            _tail = _prev;
        }
    }

}
