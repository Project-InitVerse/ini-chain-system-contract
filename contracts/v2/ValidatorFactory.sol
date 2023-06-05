// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./utils/Ownable.sol";
import "./interface/IValidator.sol";
import "./interface/IValFactory.sol";
import "./library/SortList.sol";
import "./interface/IProviderFactory.sol";
import "hardhat/console.sol";


contract Validator is Ownable,IValidator{

    uint256 public last_punish_time;
    uint256 public last_margin_time;
    uint256 public override create_time;
    uint256 public punish_start_time;
    //TODO:formal
    IValFactory public constant factory_address = IValFactory(0x000000000000000000000000000000000000c002);
    //TODO:for test
    //IValFactory public factory_address;
    uint256 public override pledge_amount;
    ValidatorState public override state;
    event Punish(address indexed,uint256 indexed,uint256 indexed);
    event MarginAdd(address indexed,uint256 indexed,uint256 indexed);
    event MarginWithdraw(address indexed,uint256 indexed);
    event StateChange(address indexed,uint256 indexed);
    struct ValidatorTotalInfo{
        address validator;
        address validator_contract;
        ValidatorState state;
        uint256 start_time;
        uint256 last_margin_time;
        uint256 last_punish_time;
        uint256 lock_time;
        uint256 margin_amount;
        uint256 punish_start_time;
    }
    constructor(){
        create_time = block.timestamp;
        pledge_amount = 0;
        state = ValidatorState.Prepare;
        emit StateChange(owner(),uint256(state));
        //TODO:for test
        //factory_address = IValFactory(msg.sender);
    }
    modifier onlyFactory(){
        require(msg.sender == address(factory_address),"only factory call this function");
        _;
    }
    function changeValidatorState(ValidatorState _state) public override onlyFactory{
        state = _state;
        emit StateChange(owner(),uint256(state));
    }
    function addMargin() public payable override onlyFactory{
        require(msg.value+ pledge_amount <= (factory_address).validator_pledgeAmount(),"posMargin must less than max validator pledge amount");
        require(msg.value > 0,"margin amount must above zero");
        last_margin_time = block.timestamp;
        pledge_amount += msg.value;
        emit MarginAdd(owner(),msg.value,pledge_amount);
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
        require(state != ValidatorState.Prepare,"only state is not prepare");
        if(owner() == block.coinbase){
            if(state == ValidatorState.Watch || state == ValidatorState.Punish){
                state = ValidatorState.Ready;
                emit StateChange(owner(),uint256(state));
            }
            if(block.timestamp - punish_start_time > factory_address.validator_punish_start_limit() && punish_start_time != 0){
                if(block.timestamp - last_punish_time > factory_address.validator_punish_interval()){
                    uint256 PunishAmount = (factory_address).getPunishAmount();
                    uint256 _punishAmount = pledge_amount >=PunishAmount  ? PunishAmount : pledge_amount;
                    if (_punishAmount > 0) {
                        pledge_amount = pledge_amount-(_punishAmount);
                        sendValue(payable((factory_address).punish_address()), _punishAmount);
                        emit Punish(owner(), _punishAmount,pledge_amount);
                    }
                }
            }
            if(pledge_amount == 0){
                state = ValidatorState.Exit;
                emit StateChange(owner(),uint256(state));
                IValFactory(factory_address).exitProduceBlock();
            }
            last_punish_time = 0;
            punish_start_time = 0;
            IValFactory(factory_address).removeRankingList();
        }else{
            if(block.timestamp - punish_start_time > factory_address.validator_punish_start_limit() && punish_start_time != 0){
                if(state != ValidatorState.Exit){
                    state = ValidatorState.Punish;
                    emit StateChange(owner(),uint256(state));
                }
                if(block.timestamp - last_punish_time > factory_address.validator_punish_interval()){
                    uint256 PunishAmount = (factory_address).getPunishAmount();
                    uint256 _punishAmount = pledge_amount >=PunishAmount  ? PunishAmount : pledge_amount;
                    if (_punishAmount > 0) {
                        pledge_amount = pledge_amount-(_punishAmount);
                        sendValue(payable((factory_address).punish_address()), _punishAmount);
                        emit Punish(owner(), _punishAmount,pledge_amount);
                    }
                    last_punish_time = block.timestamp;
                }
                if(pledge_amount == 0){
                    state = ValidatorState.Exit;
                    emit StateChange(owner(),uint256(state));
                    IValFactory(factory_address).exitProduceBlock();
                }
            }else{
                if(state == ValidatorState.Ready){
                    state = ValidatorState.Watch;
                    emit StateChange(owner(),uint256(state));
                    punish_start_time = block.timestamp;
                }
            }

        }

    }
    function exitVote() public onlyOwner{
        require((block.timestamp - last_margin_time) > factory_address.validator_lock_time(),"you cant exit util lock time end");
        pledge_amount = 0;
        uint256 balance_before = address(this).balance;
        sendValue(payable(owner()),address(this).balance);
        emit MarginWithdraw(owner(),balance_before);
    }
    function getValidatorInfo() public view returns(ValidatorTotalInfo memory){
    ValidatorTotalInfo memory info;
        info.validator = owner();
        info.validator_contract = address(this);
        info.state = state;
        info.start_time = create_time;
        info.last_margin_time = last_margin_time;
        info.last_punish_time= last_punish_time;
        info.lock_time = factory_address.validator_lock_time();
        info.margin_amount = address(this).balance;
        info.punish_start_time = punish_start_time;
        return info;
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

    uint256 public validator_lock_time;
    uint256 public validator_punish_start_limit;
    uint256 public validator_punish_interval;

    bool public initialized;
    mapping(address=>IValidator) public whiteList_validator;

    uint256 public current_challenge_provider_count;
    uint256 public max_challenge_percent;
    uint256 public challenge_all_percent;
    uint256 public max_challenge_time;
    uint256 public max_provider_start_challenge_time;
    //TODO:formal
    IProviderFactory public constant provider_factory = IProviderFactory(0x000000000000000000000000000000000000C003);
    //TODO:for test
    //IProviderFactory public provider_factory;
    uint256 public challenge_sdl_trx_id;
    event ChallengeCreate(address,uint256,uint256);
    event ChallengeEnd(address,uint256);

    mapping(address=>providerChallengeInfo[]) public provider_challenge_info;
    mapping(address=>uint256) public  provider_index;
    mapping(address=>ChallengeState) public provider_last_challenge_state;
    enum ChallengeState{
        NotStart,
        Create,
        Success,
        Fail
    }

    struct providerChallengeInfo{
        address provider;
        address challenge_validator;
        uint256 md5_seed;
        string url;
        uint256 create_challenge_time;
        uint256 challenge_finish_time;
        ChallengeState state;
        uint256 challenge_amount;
        uint256 seed;
        uint256 root_hash;
        uint256 index;
    }
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
    modifier onlyActiveValidator(){
        require(owner_validator[msg.sender] != IValidator(address(0)),"ValidatorFactory: only validator use this function");
        require(owner_validator[msg.sender].isProduceBlock(),"ValidatorFactory:this validator state wrong");
        _;
    }
    modifier onlyNotInitialize(){
        require(!initialized,"ValidatorFactory:this contract has been initialized");
        _;
    }
    modifier onlyValidator(){
        require(owner_validator[Ownable(msg.sender).owner()] != IValidator(address(0)),"ValidatorFactory: only validator contract use this function");
        _;
    }
    //TODO:for test
//    function setProviderFactory(address _provider_factory) public onlyAdmin{
//        provider_factory = IProviderFactory(_provider_factory);
//    }
    function changeChallengeSdlTrxID(uint256 _new_trx_id)public onlyAdmin{
        challenge_sdl_trx_id = _new_trx_id;
    }
    function changeMaxChallengeParam(uint256 _max_challenge_percent,uint256 _challenge_all_percent,
                        uint256 _max_challenge_time,uint256 _max_provider_start_challenge_time) public onlyAdmin{
        max_challenge_percent = _max_challenge_percent;
        challenge_all_percent = _challenge_all_percent;
        max_challenge_time = _max_challenge_time;
        max_provider_start_challenge_time = _max_provider_start_challenge_time;
    }
    function changeValidatorLockTime(uint256 _new_lock) public onlyAdmin{
        validator_lock_time = _new_lock;
    }
    function changePunishPercent(uint256 _new_punish_percent,uint256 _new_punish_all_percent)external onlyAdmin{
        require(_new_punish_percent < _new_punish_all_percent,"all percent must bigger than punish percent");
        punish_percent = _new_punish_percent;
        punish_all_percent = _new_punish_all_percent;
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

    }
    function initialize(address[]memory _init_validator,address _admin) external onlyNotInitialize{
        initialized = true;
        admin_address= _admin;
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
        max_challenge_percent = 300;
        challenge_all_percent = 1000;
        max_challenge_time = 12 * 60;
        max_provider_start_challenge_time = 8 *60;
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
    onlyMiner
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
    function getAllValidator()public view returns(ValidatorInfo[] memory){
        ValidatorInfo[] memory ret = new ValidatorInfo[](all_validators.length);
        for(uint256 i = 0;i < all_validators.length;i++){
            ret[i].validator_contract = address(all_validators[i]);
            ret[i].validator = Ownable(address(all_validators[i])).owner();
            ret[i].state = all_validators[i].state();
            ret[i].start_time = all_validators[i].create_time();
        }
        return ret;
    }
    function getProviderChallengeInfo(address provider_owner) public view returns(providerChallengeInfo memory){
        uint256 current_index = provider_index[provider_owner];
        if(current_index != 0){
            return provider_challenge_info[provider_owner][(current_index-1)%10];
        }
        providerChallengeInfo memory new_info;
        return new_info;
    }
    function challengeProvider(address provider,uint256 md5_seed,string memory url)public
    onlyActiveValidator
    {
        if(current_challenge_provider_count + 1 > provider_factory.getProviderInfoLength() * max_challenge_percent / challenge_all_percent){
            return;
        }
        if(!provider_factory.whetherCanPOR(provider)){
            return;
        }
        providerChallengeInfo memory last_provider_info = getProviderChallengeInfo(provider);
        if(last_provider_info.state == ChallengeState.Create){
            return;
        }
        uint256 current = provider_index[provider];
        providerChallengeInfo memory new_info;
        new_info.provider = provider;
        new_info.md5_seed = md5_seed;
        new_info.challenge_validator = msg.sender;
        new_info.state = ChallengeState.Create;
        new_info.url = url;
        new_info.create_challenge_time = block.timestamp;
        new_info.index = current;
        if(current == 0){
            provider_challenge_info[provider].push(new_info);
        }else{
            providerChallengeInfo memory _info = provider_challenge_info[provider][(current-1)%10];
            if(_info.state != ChallengeState.Create && _info.challenge_validator != msg.sender){
                if(current < 10){
                    provider_challenge_info[provider].push(new_info);
                }
                else{
                    provider_challenge_info[provider][current%10] = new_info;
                }
            }else{
                return;
            }
        }
        provider_factory.changeProviderState(provider,true);
        provider_index[provider] = provider_index[provider] + 1;
        current_challenge_provider_count = current_challenge_provider_count + 1;
        provider_last_challenge_state[provider] = ChallengeState.Create;
        emit ChallengeCreate(provider,md5_seed,current);
    }
    function changeValidatorChallengeState(address provider,uint256 index)public onlyAdmin{
        providerChallengeInfo storage _info = provider_challenge_info[provider][index];
        _info.state = ChallengeState.NotStart;
        provider_factory.changeProviderState(provider,false);
    }
    function validatorNotSubmitResult(address provider)public{
        uint256 current_index = provider_index[provider];
        providerChallengeInfo storage _info = provider_challenge_info[provider][(current_index-1)%10];
        require(block.timestamp - _info.create_challenge_time > max_challenge_time && _info.state == ChallengeState.Create,"this challenge has end");
        _info.challenge_finish_time = block.timestamp;
        _info.state = ChallengeState.NotStart;
        current_challenge_provider_count = current_challenge_provider_count - 1;
        provider_factory.changeProviderState(provider,false);
        provider_last_challenge_state[provider] = ChallengeState.NotStart;
        emit ChallengeEnd(provider,current_index - 1);
    }
    function challengeFinish(address provider,uint256 seed,uint256 challenge_amount,uint256 root_hash,ChallengeState _state)public{
        uint256 current_index = provider_index[provider];
        providerChallengeInfo storage _info = provider_challenge_info[provider][(current_index-1)%10];
        require(_info.challenge_validator == msg.sender && _info.state == ChallengeState.Create,"only challenger can end challenge");
        _info.challenge_finish_time = block.timestamp;
        _info.root_hash = root_hash;
        _info.seed = seed;
        _info.challenge_amount = challenge_amount;
        _info.state = _state;
        current_challenge_provider_count = current_challenge_provider_count - 1;
        provider_factory.changeProviderState(provider,false);
        if(_state == ChallengeState.Success){
            provider_factory.removePunishList(provider);
        }
        if(_state == ChallengeState.Fail){
            provider_factory.tryPunish(provider);
        }
        provider_last_challenge_state[provider] = _state;
        emit ChallengeEnd(provider,current_index-1);
    }
}
