// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./utils/Ownable.sol";
import "./interface/IValidator.sol";
import "./interface/IValFactory.sol";
import "./library/SortList.sol";
import "hardhat/console.sol";


contract Validator is Ownable,IValidator{

    uint256 public last_punish_time;
    uint256 public override create_time;
    uint256 public punish_start_time;
    //TODO:formal
    //IValFactory public constant factory_address = IValFactory(0x000000000000000000000000000000000000c002);
    //TODO:for test
    IValFactory public factory_address;
    uint256 public override pledge_amount;
    ValidatorState public override state;
    constructor(){
        create_time = block.timestamp;
        pledge_amount = 0;
        state = ValidatorState.Prepare;
        //TODO:for test
        factory_address = IValFactory(msg.sender);
    }
    modifier onlyFactory(){
        require(msg.sender == address(factory_address));
        _;
    }
    function changeValidatorState(ValidatorState _state) public override onlyFactory{
        state = _state;
    }
    function addMargin() public payable override onlyFactory{
        require(msg.value+ pledge_amount <= (factory_address).validator_pledgeAmount(),"posMargin must less than max validator pledge amount");
        pledge_amount += msg.value;
    }
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
    function isProduceBlock() override external view returns(bool){
        if(state == ValidatorState.Watch || state == ValidatorState.Ready || state == ValidatorState.Punish){
            return true;
        }else{
            return false;
        }
    }
    function punish() external override onlyFactory{
        require(state != ValidatorState.Prepare);
        if(owner() == block.coinbase){
            if(state == ValidatorState.Watch || state == ValidatorState.Punish){
                state = ValidatorState.Ready;
            }
            if(block.timestamp - punish_start_time > factory_address.validator_punish_start_limit() && punish_start_time != 0){
                if(block.timestamp - last_punish_time > factory_address.validator_punish_interval()){
                    uint256 PunishAmount = (factory_address).getPunishAmount();
                    uint256 _punishAmount = pledge_amount >=PunishAmount  ? PunishAmount : pledge_amount;
                    if (_punishAmount > 0) {
                        pledge_amount = pledge_amount-(_punishAmount);
                        sendValue(payable((factory_address).punish_address()), _punishAmount);
                        //emit Punish(validator, _punishAmount);
                    }
                }
            }
            if(pledge_amount == 0){
                state = ValidatorState.Exit;
                IValFactory(factory_address).exitProduceBlock();
            }
            last_punish_time = 0;
            punish_start_time = 0;
            IValFactory(factory_address).removeRankingList();
        }else{
            if(block.timestamp - punish_start_time > factory_address.validator_punish_start_limit() && punish_start_time != 0){
                if(state != ValidatorState.Exit){
                    state = ValidatorState.Punish;
                }
                if(block.timestamp - last_punish_time > factory_address.validator_punish_interval()){
                    uint256 PunishAmount = (factory_address).getPunishAmount();
                    uint256 _punishAmount = pledge_amount >=PunishAmount  ? PunishAmount : pledge_amount;
                    if (_punishAmount > 0) {
                        pledge_amount = pledge_amount-(_punishAmount);
                        sendValue(payable((factory_address).punish_address()), _punishAmount);
                        //emit Punish(validator, _punishAmount);
                    }
                    last_punish_time = block.timestamp;
                }
                if(pledge_amount == 0){
                    state = ValidatorState.Exit;
                    IValFactory(factory_address).exitProduceBlock();
                }
            }else{
                if(state != ValidatorState.Exit){
                    state = ValidatorState.Watch;
                    punish_start_time = block.timestamp;
                }
            }

        }

    }
    function exitVote() public onlyOwner{
        require((block.timestamp - create_time) > factory_address.validator_lock_time(),"you cant exit util lock time end");
        pledge_amount = 0;
        sendValue(payable(owner()),address(this).balance);
    }
}


contract ValidatorFactory  {
    using SortLinkedList for SortLinkedList.List;
    uint256 public max_validator_count;
    uint256 public validator_pledgeAmount;
    uint256 public current_validator_count;
    uint256 public team_percent;
    uint256 public validator_percent;
    uint256 public all_percent;
    address public team_address;

    address public punish_address;
    uint256 public punish_percent;
    uint256 public punish_all_percent;

    address public admin_address;
    address public providerFactory;

    uint256 public validator_lock_time;
    uint256 public validator_punish_start_limit;
    uint256 public validator_punish_interval;

    bool public initialized;
    mapping(address=>IValidator) public whiteList_validator;
    struct ValidatorInfo{
        address validator;
        address validator_contract;
        ValidatorState state;
        uint256 start_time;
    }
    mapping(address=>IValidator)public owner_validator;
    IValidator[] public all_validators;
    SortLinkedList.List validatorPunishPools;
    modifier onlyMiner() {
        require(msg.sender == block.coinbase, "Miner only");
        _;
    }
    modifier onlyAdmin(){
        require(msg.sender == admin_address,"ValidatorFactory:only admin use this function");
        _;
    }
    modifier onlyNotInitialize(){
        require(!initialized,"ValidatorFactory:this contract has been initialized");
        _;
    }
    modifier onlyValidator(){
        require(owner_validator[msg.sender] != IValidator(address(0)));
        _;
    }
    function setProviderFactory(address _provider_factory) public onlyAdmin{
        providerFactory = _provider_factory;
    }
    function changeValidatorLockTime(uint256 _new_lock) public onlyAdmin{
        validator_lock_time = _new_lock;
    }
    function changeValidatorPunishStartTime(uint256 _new_start_limit) public onlyAdmin{
        validator_punish_start_limit = _new_start_limit;
    }
    function changeValidatorPunishInterval(uint256 _new_interval) public onlyAdmin{
        validator_punish_interval =_new_interval;
    }
    function changeAdminAddress(address _new_admin) public onlyAdmin{
        require(_new_admin != address(0));
        admin_address = _new_admin;
    }
    function changePunishAddress(address _punish_address) public onlyAdmin{
        punish_address = _punish_address;
    }
    function changeTeamAddress(address _team_address) public onlyAdmin{
        team_address = _team_address;
    }
    function changeRewardPercent(uint256 _team_percent,uint256 _validator_percent,uint256 _all_percent) public onlyAdmin{
        require(_team_percent+_validator_percent <= _all_percent);
        team_percent = _team_percent;
        validator_percent = _validator_percent;
        all_percent = _all_percent;
    }
    function changeMaxValidatorCount(uint256 _max_validator_count) public onlyAdmin{
        max_validator_count = _max_validator_count;
    }
    function changeValidatorMinPledgeAmount(uint256 _validator_min_pledgeAmount) public onlyAdmin{
        validator_pledgeAmount = _validator_min_pledgeAmount;
    }
    function getAllValidatorLength() public view returns(uint256){
        return all_validators.length;
    }
    constructor(){
        max_validator_count = 61;
        validator_pledgeAmount = 50000 ether;
        team_percent = 400;
        validator_percent = 1000;
        all_percent = 10000;
        validator_lock_time = 365 days;
        validator_punish_start_limit = 48 hours;
        validator_punish_interval = 1 hours;
        punish_percent = 100;
        punish_all_percent = 10000;
    }
    function initialize(address[]memory _init_validator,address _admin) external onlyNotInitialize{
        initialized = true;
        admin_address= _admin;
        for(uint256 i = 0;i < _init_validator.length;i++){
            IValidator new_validator = new Validator{salt: keccak256(abi.encodePacked(_init_validator[i]))}();
            new_validator.changeValidatorState(ValidatorState.Ready);
            current_validator_count = current_validator_count+1;
            Ownable(address(new_validator)).transferOwnership(_init_validator[i]);
            whiteList_validator[_init_validator[i]] = new_validator;
            owner_validator[_init_validator[i]] = new_validator;
            all_validators.push(new_validator);
        }

    }
    function changeValidatorState(address validator,ValidatorState _state)onlyAdmin public {
        owner_validator[validator].changeValidatorState(_state);
        if(_state == ValidatorState.Ready){
            current_validator_count = current_validator_count+1;
        }
    }
    function createValidator()public payable returns(address){
        require(msg.value == validator_pledgeAmount,"ValidatorFactory: not enough value to be a validator");
        require(current_validator_count + 1 <= max_validator_count,"ValidatorFactory: cant register validator");
        require(owner_validator[msg.sender] == IValidator(address(0)),"ValidatorFactory: this account has register validator");
        IValidator new_validator = new Validator{salt: keccak256(abi.encodePacked(msg.sender))}();
        new_validator.addMargin{value: msg.value}();
        Ownable(address(new_validator)).transferOwnership(msg.sender);
        owner_validator[msg.sender] = new_validator;
        all_validators.push(new_validator);
        return address(new_validator);
    }
    function MarginCalls()public payable {
        require(owner_validator[msg.sender] != IValidator(address(0)),"ValidatorFactory : you account is not a validator");
        owner_validator[msg.sender].addMargin{value:msg.value}();
    }
    function removeRankingList()public onlyValidator{
        IValidator _pool = IValidator(msg.sender);
        SortLinkedList.List storage _list = validatorPunishPools;
        _list.removeRanking(_pool);
    }
    function exitProduceBlock() public onlyValidator{
        current_validator_count--;
    }
    function getPunishAmount() public view returns(uint256){
        return validator_pledgeAmount * punish_percent / punish_all_percent;
    }
    function tryPunish(address val)public
    //TODO for formal
    //onlyMiner
    {
        if(val != address(0)){
            if(whiteList_validator[val] == IValidator(address(0))){
                require(owner_validator[val] != IValidator(address(0)),"ValidatorFactory: not validator");
                SortLinkedList.List storage _list = validatorPunishPools;
                _list.improveRanking(owner_validator[val]);
            }
        }
        SortLinkedList.List storage _valPunishPool = validatorPunishPools;
        IValidator _cur = _valPunishPool.head;
        while (_cur != IValidator(address(0))) {
            _cur.punish();
            _cur = _valPunishPool.next[_cur];
        }
    }
    function getAllPunishValidator() public view returns(address[] memory){
        address[] memory ret = new address[](validatorPunishPools.length);
        SortLinkedList.List storage _valPunishPool = validatorPunishPools;
        IValidator _cur = _valPunishPool.head;
        uint256 index = 0;
        while (_cur != IValidator(address(0))) {
            ret[index] = Ownable(address(_cur)).owner();
            _cur = _valPunishPool.next[_cur];
        }
        return ret;
    }
    function getAllActiveValidatorAddr() external view returns(address[] memory){
        uint256 _count = 0;
        for(uint256 i = 0;i < all_validators.length;i++){
            if(all_validators[i].isProduceBlock()){
                _count++;
            }
        }
        address[] memory ret = new address[](_count);
        uint256 index = 0;
        for(uint256 i = 0;i < all_validators.length;i++){
            if(all_validators[i].isProduceBlock()){
                ret[index] = Ownable(address(all_validators[i])).owner();
                index++;
            }
        }
        return ret;
    }
    function getAllActiveValidator() public view returns(ValidatorInfo[] memory){
        uint256 _count = 0;
        for(uint256 i = 0;i < all_validators.length;i++){
            if(all_validators[i].isProduceBlock()){
                _count++;
            }
        }
        ValidatorInfo[] memory ret = new ValidatorInfo[](_count);
        uint256 index = 0;
        for(uint256 i = 0;i < all_validators.length;i++){
            if(all_validators[i].isProduceBlock()){
                ret[index].validator_contract = address(all_validators[i]);
                ret[index].validator = Ownable(address(all_validators[i])).owner();
                ret[index].state = all_validators[i].state();
                ret[index].start_time = all_validators[i].create_time();
                index++;
            }
        }
        return ret;
    }
}
