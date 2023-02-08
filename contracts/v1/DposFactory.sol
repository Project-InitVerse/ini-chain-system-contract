// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./Params.sol";
import "./DposPledge.sol";
import "./library/SortedList.sol";
import "./interfaces/IDposPledge.sol";
import "./interfaces/IDposFactory.sol";


contract DposFactory is Params, IDposFactory {
    using SortedLinkedList for SortedLinkedList.List;
    struct ValidatorInfo{
        address validator;
        address validator_contract;
        uint256 voting_amount;
    }
    struct ValidatorUserInfo{
        address validator;
        address validator_contract;
        uint256 voting_amount;
        address user;
        uint256 user_voting_amount;
        uint256 user_unpay_reward;
    }
    address public admin;

    uint256 public count;
    uint256 public backupCount;
    uint256 constant first_part_percent= 10;
    uint256 constant second_part_percent = 40;
    uint256 constant third_part_percent = 50;
    uint256 constant precision= 100;
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
            DposPledge _pool = new DposPledge(_validator, PERCENT_BASE/10, State.Ready);
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
        //SortedLinkedList.List storage _lista = topVotePools;

        uint256 _size = count;
        IDposPledge cur = _list.head;
        while (_size > 0 && cur != IDposPledge(address(0))) {
            _topValidators[_index] = cur.validator();
            _index++;
            _size--;
            cur = _list.next[cur];
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

        uint _left = msg.value+rewardLeft;

        // 10% to backups 40% validators share by vote 50% validators share
        uint _firstPart = _left*first_part_percent/precision;
        uint _secondPartTotal = _left*second_part_percent/precision;
        uint _thirdPart = _left*third_part_percent/precision;

        if (backupValidators.length > 0) {
            uint _totalBackupVote = 0;
            for (uint8 i = 0; i < backupValidators.length; i++) {
                _totalBackupVote = _totalBackupVote+dposPledges[backupValidators[i]].totalVote();
            }

            if (_totalBackupVote > 0) {
                for (uint8 i = 0; i < backupValidators.length; i++) {
                    IDposPledge _pool = dposPledges[backupValidators[i]];
                    uint256 _reward = _firstPart*_pool.totalVote()/_totalBackupVote;
                    pendingReward[_pool] = pendingReward[_pool]+_reward;
                    _left = _left-_reward;
                }
            }
        }

        if (activeValidators.length > 0) {
            uint _totalVote = 0;
            for (uint8 i = 0; i < activeValidators.length; i++) {
                _totalVote = _totalVote+dposPledges[activeValidators[i]].totalVote();
            }

            for (uint8 i = 0; i < activeValidators.length; i++) {
                IDposPledge _pool = dposPledges[activeValidators[i]];
                uint _reward = _thirdPart/activeValidators.length;
                if (_totalVote > 0) {
                    uint _secondPart = _pool.totalVote()*_secondPartTotal/_totalVote;
                    _reward = _reward+_secondPart;
                }

                pendingReward[_pool] = pendingReward[_pool]+_reward;
                _left = _left-_reward;
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
    function getAllValidate() public view returns(ValidatorInfo[] memory){
        uint256 length = allValidators.length;
        ValidatorInfo[] memory _validators =new ValidatorInfo[](length);
        for (uint256 i = 0;i < length;i++){
            _validators[i].validator = allValidators[i];
            _validators[i].validator_contract = address(dposPledges[_validators[i].validator]);
            _validators[i].voting_amount = dposPledges[allValidators[i]].totalVote();
        }
        return _validators;
    }
    function getUserValidate(address user) public view returns (ValidatorUserInfo[] memory){
        uint256 _count = 0;
        for (uint256 i = 0;i < allValidators.length;i++){
            if (dposPledges[allValidators[i]].getVoterInfo(user).amount > 0){
                _count = _count + 1;
            }
        }
        ValidatorUserInfo[] memory _validators_user =new ValidatorUserInfo[](_count);
        uint256 index = 0;
        for (uint256 i = 0;i < allValidators.length;i++){
            if (dposPledges[allValidators[i]].getVoterInfo(user).amount > 0){
                _validators_user[index].validator = allValidators[i];
                _validators_user[index].validator_contract = address(dposPledges[allValidators[i]]);
                _validators_user[index].voting_amount = dposPledges[allValidators[i]].totalVote();
                _validators_user[index].user = user;
                _validators_user[index].user_unpay_reward = dposPledges[allValidators[i]].getPendingReward(user);
                _validators_user[index].user_voting_amount = dposPledges[allValidators[i]].getVoterInfo(user).amount;
                index = index + 1;
            }
        }
        return _validators_user;
    }
    /*
    //TODO : for test
    function switchState(address pool,bool state)external{
        dposPledges[pool].switchState(state);
    }
    */
}
