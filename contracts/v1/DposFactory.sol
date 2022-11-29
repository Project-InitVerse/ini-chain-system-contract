// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./Params.sol";
import "./library/SafeMath.sol";
import "./DposPledge.sol";
import "./library/SortedList.sol";
import "./interfaces/IDposPledge.sol";
import "./interfaces/IDposFactory.sol";


contract DposFactory is Params, IDposFactory {
    using SafeMath for uint256;
    using SortedLinkedList for SortedLinkedList.List;

    address public admin;

    uint256 public count;
    uint256 public backupCount;

    address[] activeValidators;
    address[] backupValidators;
    mapping(address => uint8) actives;

    address[] public allValidators;
    mapping(address => IDposPledge) public override dposPledges;

    uint256 rewardLeft;
    mapping(IDposPledge => uint) public override pendingReward;
    mapping(uint256 => mapping(Operation => bool)) operationsDone;

    SortedLinkedList.List topVotePools;


    event ChangeAdmin(address indexed admin);

    event AddValidator(address indexed validator, address votePool);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    modifier onlyRegistered() {
        IDposPledge _pool = IDposPledge(msg.sender);
        require(dposPledges[_pool.validator()] == _pool, "Vote pool not registered");
        _;
    }
    modifier onlyNotOperated(Operation operation) {
        require(!operationsDone[block.number][operation], "Already operated");
        _;
    }

    function initialize(address[] memory _validators, address _admin)
    external
    onlyNotInitialized {
        require(_validators.length > 0 , "Invalid params");
        require(_admin != address(0), "Invalid admin address");

        initialized = true;
        admin = _admin;

        count = 15;
        backupCount = 0;

        for (uint8 i = 0; i < _validators.length; i++) {
            address _validator = _validators[i];
            require(dposPledges[_validator] == IDposPledge(address(0)), "Validators already exists");
            DposPledge _pool = new DposPledge(_validator, PERCENT_BASE.div(10), State.Ready);
            allValidators.push(_validator);
            dposPledges[_validator] = _pool;
            //TODO :for test
            //_pool.setAddress(address(this), address(0));
            _pool.initialize();
        }
    }

    function changeAdmin(address _newAdmin)
    external
    onlyValidAddress(_newAdmin)
    onlyAdmin {
        admin = _newAdmin;
        emit ChangeAdmin(admin);
    }

    function updateActiveValidatorSet(address[] memory newSet, uint256 epoch)
    external
    //TODO: for test
    onlyMiner
    onlyBlockEpoch(epoch)
    onlyNotOperated(Operation.UpdateValidators)
    onlyInitialized
    {
        operationsDone[block.number][Operation.UpdateValidators] = true;

        for (uint256 i = 0; i < activeValidators.length; i ++) {
            actives[activeValidators[i]] = 0;
        }

        activeValidators = newSet;
        for (uint256 i = 0; i < activeValidators.length; i ++) {
            actives[activeValidators[i]] = 1;
        }

        delete backupValidators;

        uint256 _size = backupCount;
        SortedLinkedList.List storage _topList = topVotePools;
        IDposPledge _cur = _topList.head;
        while (_size > 0 && _cur != IDposPledge(address(0))) {
            if (actives[_cur.validator()] == 0) {
                backupValidators.push(_cur.validator());
                _size--;
            }
            _cur = _topList.next[_cur];
        }
    }

    function addValidator(address _validator, uint _percent)
    external
    returns (address) {
        require(dposPledges[_validator] == IDposPledge(address(0)), "Validators already exists");

        DposPledge _pool = new DposPledge(_validator, _percent, State.Idle);

        allValidators.push(_validator);
        dposPledges[_validator] = _pool;

        emit AddValidator(_validator, address(_pool));

        return address(_pool);
    }

    function updateValidatorState(address _validator, bool pause)
    external
    onlyAdmin {
        require(dposPledges[_validator] != IDposPledge(address(0)), "Corresponding vote pool not found");
        dposPledges[_validator].switchState(pause);
    }

    function getTopValidators()
    external
    view
    returns (address[] memory) {
        uint256 _count = 0;
        SortedLinkedList.List storage _list = topVotePools;
        if (_list.length < count) {
            _count += _list.length;
        } else {
            _count += count;
        }

        address[] memory _topValidators = new address[](_count);

        uint256 _index = 0;
        SortedLinkedList.List storage _lista = topVotePools;

        uint256 _size = count;
        IDposPledge cur = _lista.head;
        while (_size > 0 && cur != IDposPledge(address(0))) {
            _topValidators[_index] = cur.validator();
            _index++;
            _size--;
            cur = _lista.next[cur];
        }

        return _topValidators;
    }


    function getActiveValidators()
    external
    view
    returns (address[] memory){
        return activeValidators;
    }

    function getBackupValidators()
    external
    view
    returns (address[] memory){
        return backupValidators;
    }

    function getAllValidatorsLength()
    external
    view
    returns (uint){
        return allValidators.length;
    }

    function distributeBlockReward()
    external
    payable
        // #if Mainnet
    //TODO : for test
    onlyMiner
        // #endif
    onlyNotOperated(Operation.Distribute)
    onlyInitialized
    {
        operationsDone[block.number][Operation.Distribute] = true;

        uint _left = msg.value.add(rewardLeft);

        // 10% to backups 40% validators share by vote 50% validators share
        uint _firstPart = _left.mul(10).div(100);
        uint _secondPartTotal = _left.mul(40).div(100);
        uint _thirdPart = _left.mul(50).div(100);

        if (backupValidators.length > 0) {
            uint _totalBackupVote = 0;
            for (uint8 i = 0; i < backupValidators.length; i++) {
                _totalBackupVote = _totalBackupVote.add(dposPledges[backupValidators[i]].totalVote());
            }

            if (_totalBackupVote > 0) {
                for (uint8 i = 0; i < backupValidators.length; i++) {
                    IDposPledge _pool = dposPledges[backupValidators[i]];
                    uint256 _reward = _firstPart.mul(_pool.totalVote()).div(_totalBackupVote);
                    pendingReward[_pool] = pendingReward[_pool].add(_reward);
                    _left = _left.sub(_reward);
                }
            }
        }

        if (activeValidators.length > 0) {
            uint _totalVote = 0;
            for (uint8 i = 0; i < activeValidators.length; i++) {
                _totalVote = _totalVote.add(dposPledges[activeValidators[i]].totalVote());
            }

            for (uint8 i = 0; i < activeValidators.length; i++) {
                IDposPledge _pool = dposPledges[activeValidators[i]];
                uint _reward = _thirdPart.div(activeValidators.length);
                if (_totalVote > 0) {
                    uint _secondPart = _pool.totalVote().mul(_secondPartTotal).div(_totalVote);
                    _reward = _reward.add(_secondPart);
                }

                pendingReward[_pool] = pendingReward[_pool].add(_reward);
                _left = _left.sub(_reward);
            }
        }

        rewardLeft = _left;
    }

    function withdrawReward()
    override
    external {
        uint _amount = pendingReward[IDposPledge(msg.sender)];
        if (_amount == 0) {
            return;
        }

        pendingReward[IDposPledge(msg.sender)] = 0;
        DposPledge(msg.sender).receiveReward{value : _amount}();
    }

    function improveRanking()
    external
    override
    onlyRegistered {
        IDposPledge _pool = IDposPledge(msg.sender);
        require(_pool.state() == State.Ready, "Incorrect state");

        SortedLinkedList.List storage _list = topVotePools;
        _list.improveRanking(_pool);
    }

    function lowerRanking()
    external
    override
    onlyRegistered {
        IDposPledge _pool = IDposPledge(msg.sender);
        require(_pool.state() == State.Ready, "Incorrect state");

        SortedLinkedList.List storage _list = topVotePools;
        _list.lowerRanking(_pool);
    }

    function removeRanking()
    external
    override
    onlyRegistered {
        IDposPledge _pool = IDposPledge(msg.sender);

        SortedLinkedList.List storage _list = topVotePools;
        _list.removeRanking(_pool);
    }
    /*
    //TODO : for test
    function switchState(address pool,bool state)external{
        dposPledges[pool].switchState(state);
    }
    */
}
