// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./ReentrancyGuard.sol";
import "./InterfaceProvider.sol";
import "./InterfaceAuditor.sol";
import "./InterfaceOrderFactory.sol";


contract Provider is IProvider,ReentrancyGuard{
    poaResource public total;
    poaResource public used;
    poaResource public lock;
    bool public challenge;
    ProviderState state;
    address public override owner;
    string public region;
    uint256 public provider_first_margin_time;
    uint256 public last_margin_time;
    uint256 public last_challenge_time;
    uint256 public margin_block;
    uint256 public punish_start_margin_amount;
    string  public override info;
    IProviderFactory provider_factory;
    constructor(uint256 cpu_count,
        uint256 mem_count,
        uint256 storage_count,
        address _owner,
        string memory _region,
        string memory provider_info){
        provider_factory = IProviderFactory(msg.sender);
        total.cpu_count = cpu_count;
        total.memory_count = mem_count;
        total.storage_count = storage_count;
        owner = _owner;
        info = provider_info;
        challenge = false;
        region = _region;
        state = ProviderState.Running;
        provider_first_margin_time = block.timestamp;
        last_margin_time= block.timestamp;
        margin_block = block.number;
    }
    function triggerMargin() external{
        margin_block = block.number;
        last_margin_time = block.timestamp;
    }
    event ProviderResourceChange(address);
    modifier onlyFactory(){
        require(msg.sender == address(provider_factory));
        _;
    }
    modifier onlyOwner{
        require(msg.sender == owner,"Provider:only owner can use this function");
        _;
    }
    modifier onlyNotStop{
        require(state != ProviderState.Stop);
        _;
    }
    function changeProviderInfo(string memory new_info) public onlyOwner{
        info = new_info;
    }
    function changeRegion(string memory _new_region) public onlyOwner{
        region = _new_region;
    }
    function getDetail() external view override returns(providerInfo memory){
        providerInfo memory ret;
        ret.total = total;
        ret.used = used;
        ret.lock = lock;
        ret.region = region;
        ret.state = state;
        ret.owner = owner;
        ret.info = info;
        ret.challenge = challenge;
        return ret;
    }

    function getLeftResource() external override view returns(poaResource memory){
        poaResource memory left;
        left.cpu_count = total.cpu_count - used.cpu_count;
        left.memory_count = total.memory_count-used.memory_count;
        left.storage_count = total.storage_count - used.storage_count;
        return left;
    }
    function getTotalResource() external override view returns(poaResource memory){
        return total;
    }
    function challengeProvider() external override onlyFactory{
        challenge = true;
        last_challenge_time = block.timestamp;
        provider_factory.changeProviderResource(total.cpu_count,total.memory_count,total.storage_count,false);
        lock.cpu_count = total.cpu_count - used.cpu_count;
        lock.memory_count = total.memory_count - used.memory_count;
        lock.storage_count = total.storage_count - used.storage_count;
        provider_factory.changeProviderResource(used.cpu_count,used.memory_count,used.storage_count,true);
    }

    function consumeResource(uint256 consume_cpu,uint256 consume_mem,uint256 consume_storage) external override onlyFactory nonReentrant{
        require(consume_cpu <= total.cpu_count - used.cpu_count,"Provider:cpu is not enough");
        require(consume_mem <= total.memory_count-used.memory_count,"Provider:mem is not enough");
        require(consume_storage <= total.storage_count - used.storage_count,"Provider:storage is not enough");
        provider_factory.changeProviderUsedResource(used.cpu_count,used.memory_count,used.storage_count,false);
        used.cpu_count= used.cpu_count + consume_cpu;
        used.memory_count = used.memory_count + consume_mem;
        used.storage_count = used.storage_count + consume_storage;
        provider_factory.changeProviderUsedResource(used.cpu_count,used.memory_count,used.storage_count,true);
        emit ProviderResourceChange(address(this));
    }
    function recoverResource(uint256 consumed_cpu,uint256 consumed_mem,uint256 consumed_storage) external override onlyFactory nonReentrant{
        if((consumed_cpu >  used.cpu_count) ||
           (consumed_mem >  used.memory_count ) ||
           (consumed_storage > used.storage_count)){
            provider_factory.changeProviderResource(total.cpu_count,total.memory_count,total.storage_count,false);
            total.cpu_count = used.cpu_count;
            total.memory_count = used.memory_count;
            total.storage_count = used.storage_count;
            provider_factory.changeProviderResource(used.cpu_count,used.memory_count,used.storage_count,true);
        }else{
            provider_factory.changeProviderUsedResource(used.cpu_count,used.memory_count,used.storage_count,false);
            used.cpu_count = used.cpu_count - consumed_cpu;
            used.memory_count = used.memory_count - consumed_mem;
            used.storage_count = used.storage_count - consumed_storage;
            provider_factory.changeProviderUsedResource(used.cpu_count,used.memory_count,used.storage_count,true);
        }
        emit ProviderResourceChange(address(this));
    }
    function updateResource(uint256 new_cpu_count,uint256 new_mem_count, uint256 new_sto_count) external onlyOwner onlyNotStop{
        provider_factory.changeProviderResource(total.cpu_count,total.memory_count,total.storage_count,false);
        total.cpu_count = used.cpu_count + new_cpu_count;
        total.memory_count = used.memory_count + new_mem_count;
        total.storage_count = used.storage_count + new_sto_count;
        provider_factory.changeProviderResource(total.cpu_count,total.memory_count,total.storage_count,true);
        emit ProviderResourceChange(address(this));
    }
}
contract ProviderFactory is IProviderFactory,ReentrancyGuard {
    constructor (address _admin,address _order_factory,address _auditor_factory){
        admin = _admin;
        order_factory = _order_factory;
        auditor_factory = _auditor_factory;
    }
    uint256 constant public MIN_VALUE_TO_BE_PROVIDER = 0 ether;
    poaResource total_all;
    poaResource total_used;
    mapping(address => IProvider) public providers;
    mapping(address => uint256) public provider_pledge;
    IProvider[] providerArray;
    address public order_factory;
    address public admin;
    address public auditor_factory;
    struct providerInfos{
        address provider_contract;
        providerInfo info;
        uint256 margin_amount;
        address[] audits;
    }
    event ProviderCreate(address);


    modifier onlyAdmin() {
        require(msg.sender == admin, "admin  only");
        _;
    }
    modifier onlyProvider(){
        require(providers[IProvider(msg.sender).owner()] != IProvider(address(0)),"ProviderFactory: only provider can use this function");
        _;
    }
    modifier onlyNotProvider(){
        require(providers[msg.sender] == IProvider(address(0)),"ProviderFactory: only not provider can use this function");
        _;
    }
    function addMargin() public  payable{
        require(providers[msg.sender] != IProvider(address(0)),"ProviderFactory: only provider owner use this function");
        provider_pledge[msg.sender] =provider_pledge[msg.sender] + msg.value;
        providers[msg.sender].triggerMargin();
    }
    function createNewProvider(uint256 cpu_count,
        uint256 mem_count,
        uint256 storage_count,
        string memory region,
        string memory provider_info)
    onlyNotProvider
    public payable returns(address){
        require(msg.value > clacProviderAmount(cpu_count,mem_count,storage_count),"ProviderFactory: you must pledge money to be a provider");
        Provider provider_contract = new Provider(cpu_count,mem_count,storage_count,msg.sender,region,provider_info);

        total_all.cpu_count = total_all.cpu_count + cpu_count;
        total_all.memory_count  = total_all.memory_count  + mem_count;
        total_all.storage_count= total_all.storage_count + storage_count;

        providerArray.push(provider_contract);
        providers[msg.sender] = provider_contract;
        provider_pledge[msg.sender] = msg.value;
        emit ProviderCreate(address(provider_contract));
        return address(provider_contract);
    }
    function closeProvider()public onlyProvider{
        poaResource memory temp_total = providers[msg.sender].getTotalResource();
        poaResource memory temp_left = providers[msg.sender].getLeftResource();
        require(temp_total.cpu_count == temp_left.cpu_count);
        require(temp_total.memory_count == temp_left.memory_count);
        require(temp_total.storage_count == temp_left.storage_count);

        total_all.cpu_count = total_all.cpu_count - temp_total.cpu_count;
        total_all.memory_count  = total_all.memory_count -temp_total.memory_count;
        total_all.storage_count= total_all.storage_count -temp_total.storage_count;

        payable(msg.sender).transfer(provider_pledge[msg.sender]);
    }
    function clacProviderAmount(uint256 cpu_count,uint256 memory_count,uint256 storage_amount)public pure returns(uint256){
        return MIN_VALUE_TO_BE_PROVIDER;
    }
    function reOpenProvider()public payable onlyProvider{
        //TODO change state
        require(msg.value > MIN_VALUE_TO_BE_PROVIDER);
    }
    function changeOrderFactory(address new_order_factory) public onlyAdmin{
        require(new_order_factory != address(0));
        order_factory = new_order_factory;
    }
    function changeAuditorFactory(address new_audit_factory) public onlyAdmin{
        require(new_audit_factory != address(0));
        auditor_factory = new_audit_factory;
    }
    function changeAdmin(address new_admin) public onlyAdmin{
        require(admin != address(0));
        admin = new_admin;
    }
    function getProvideContract(address account) external override view returns(address){
        return address(providers[account]);
    }
    function getProvideResource(address account) external override view returns(poaResource memory){
        require(account != address(0));
        require(address(providers[IProvider(account).owner()]) == account,"ProviderFactory : this provider doesnt exist");
        return IProvider(account).getLeftResource();
    }
    function getProvideTotalResource(address account) external override view returns(poaResource memory){
        require(account != address(0));
        require(address(providers[IProvider(account).owner()]) == account,"ProviderFactory : this provider doesnt exist");
        return IProvider(account).getTotalResource();
    }
    function changeProviderResource(uint256 cpu_count, uint256 mem_count, uint256 storage_count, bool add) external onlyProvider override{
        if (add){
            total_all.cpu_count = total_all.cpu_count + cpu_count;
            total_all.memory_count = total_all.memory_count + mem_count;
            total_all.storage_count = total_all.storage_count + storage_count;
        }else{
            total_all.cpu_count = total_all.cpu_count - cpu_count;
            total_all.memory_count = total_all.memory_count - mem_count;
            total_all.storage_count = total_all.storage_count - storage_count;
        }
    }
    function changeProviderUsedResource(uint256 cpu_count, uint256 mem_count, uint256 storage_count, bool add) external override onlyProvider{
        if (add){
            total_used.cpu_count = total_used.cpu_count + cpu_count;
            total_used.memory_count = total_used.memory_count + mem_count;
            total_used.storage_count = total_used.storage_count + storage_count;
        }else{
            total_used.cpu_count = total_used.cpu_count - cpu_count;
            total_used.memory_count = total_used.memory_count - mem_count;
            total_used.storage_count = total_used.storage_count - storage_count;
        }
    }
    function consumeResource(address account,uint256 cpu_count, uint256 mem_count, uint256 storage_count)external override nonReentrant{
        require(IOrderFactory(order_factory).checkIsOrder(msg.sender) >0,"ProviderFactory : not order user");
        require(account != address(0));
        require(address(providers[IProvider(account).owner()]) == account);
        IProvider(account).consumeResource(cpu_count,mem_count,storage_count);
    }
    function recoverResource(address account,uint256 cpu_count, uint256 mem_count, uint256 storage_count)external override nonReentrant{
        require(IOrderFactory(order_factory).checkIsOrder(msg.sender)>0,"ProviderFactory : not order user");
        require(account != address(0));
        require(address(providers[IProvider(account).owner()]) == account);
        IProvider(account).recoverResource(cpu_count,mem_count,storage_count);
    }
    function getProviderInfoLength() public view returns(uint256){
        return providerArray.length;
    }
     function getTotalDetail() external view returns(poaResource memory,poaResource memory){
        return (total_all,total_used);
    }
    function getProviderSingle(address _provider_contract) public view returns(providerInfos memory){
        require(address(providers[IProvider(_provider_contract).owner()]) == _provider_contract,"ProviderFactory: provider_contract error");
        providerInfos memory _providerInfos;
        _providerInfos.info = IProvider(_provider_contract).getDetail();
        _providerInfos.provider_contract = _provider_contract;
        if(auditor_factory != address(0)){
            _providerInfos.audits = IAuditorFactory(auditor_factory).getProviderAuditors(_provider_contract);
        }
        _providerInfos.margin_amount = provider_pledge[IProvider(_provider_contract).owner()];
        return _providerInfos;
    }
    function getProviderInfo(uint256 start,uint256 limit) public view returns(providerInfos[] memory){
        require(providerArray.length > 0);
        uint256 _limit= limit;
        if(limit == 0){
            require(start == 0,"ProviderFactory:get all must start with zero");
            _limit = providerArray.length;
        }
        require(start < providerArray.length,"ProviderFactory:start must below providerArray length");
        uint256 _count = providerArray.length - start;
        if (providerArray.length - start > _limit){
            _count = _limit;
        }
        providerInfos[] memory _providerInfos =new providerInfos[](_count);
        for(uint256 i = 0;i < _count;i++){
            _providerInfos[i].info = IProvider(providerArray[i]).getDetail();
            _providerInfos[i].provider_contract = address(providerArray[i]);
            if(auditor_factory != address(0)){
                _providerInfos[i].audits = IAuditorFactory(auditor_factory).getProviderAuditors(address(providerArray[i]));
            }
            _providerInfos[i].margin_amount = provider_pledge[IProvider(providerArray[i]).owner()];
        }
        return _providerInfos;
    }
}
