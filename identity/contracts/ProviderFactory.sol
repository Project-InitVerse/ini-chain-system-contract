// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./ReentrancyGuard.sol";
import "./InterfaceProvider.sol";
import "./InterfaceAuditor.sol";
import "./InterfaceOrderFactory.sol";

contract Provider is IProvider,ReentrancyGuard{
    uint256 public total_cpu;
    uint256 public total_mem;
    uint256 public total_storage;
    uint256 public used_cpu = 0;
    uint256 public used_mem = 0;
    uint256 public used_storage = 0;
    address public override owner;
    string  public override info;
    bool public override isActive;
    IProviderFactory provider_factory;
    constructor(uint256 cpu_count, uint256 mem_count, uint256 storage_count, address _owner, string memory provider_info){
        provider_factory = IProviderFactory(msg.sender);
        total_cpu = cpu_count;
        total_mem = mem_count;
        total_storage = storage_count;
        owner = _owner;
        info = provider_info;
        isActive = true;
    }
    modifier onlyFactory(){
        require(msg.sender == address(provider_factory));
        _;
    }
    modifier onlyOwner{
        require(msg.sender == owner,"Provider:only owner can use this function");
        _;
    }
    modifier onlyActive{
        require(isActive);
        _;
    }
    function changeProviderInfo(string memory new_info) public onlyOwner{
        info = new_info;
    }
    function getLeftResource() external override view returns(uint256,uint256,uint256){
        return (total_cpu - used_cpu, total_mem - used_mem,total_storage - used_storage);
    }
    function getTotalResource() external override view returns(uint256,uint256,uint256){
        return (total_cpu,total_mem,total_storage);
    }
    function changeActive(bool active) external onlyFactory{
        isActive = active;
    }
    function consumeResource(uint256 consume_cpu,uint256 consume_mem,uint256 consume_storage) external override onlyFactory nonReentrant{
        require(consume_cpu <= total_cpu - used_cpu,"Provider:cpu is not enough");
        require(consume_mem <= total_mem - used_mem,"Provider:mem is not enough");
        require(consume_storage <= total_storage - used_storage,"Provider:storage is not enough");
        provider_factory.changeProviderUsedResource(used_cpu,used_mem,used_storage,false);
        used_cpu = used_cpu + consume_cpu;
        used_mem = used_mem + consume_mem;
        used_storage = used_storage + consume_storage;
        provider_factory.changeProviderUsedResource(used_cpu,used_mem,used_storage,true);
    }
    function recoverResource(uint256 consumed_cpu,uint256 consumed_mem,uint256 consumed_storage) external override onlyFactory nonReentrant{
        if((consumed_cpu > used_cpu) ||
           (consumed_mem > used_mem ) ||
           (consumed_storage > used_storage)){
            provider_factory.changeProviderResource(total_cpu,total_mem,total_storage,false);
            total_cpu = used_cpu;
            total_mem = used_mem;
            total_storage = used_storage;
            provider_factory.changeProviderResource(used_cpu,used_mem,used_storage,true);
        }else{
            provider_factory.changeProviderUsedResource(used_cpu,used_mem,used_storage,false);
            used_cpu = used_cpu - consumed_cpu;
            used_mem = used_mem - consumed_mem;
            used_storage = used_storage - consumed_storage;
            provider_factory.changeProviderUsedResource(used_cpu,used_mem,used_storage,true);
        }
    }
    function updateResource(uint256 new_cpu_count,uint256 new_mem_count, uint256 new_sto_count) external onlyOwner onlyActive{
        provider_factory.changeProviderResource(total_cpu,total_mem,total_storage,false);
        total_cpu = used_cpu + new_cpu_count;
        total_mem = used_mem + new_mem_count;
        total_storage = used_storage + new_sto_count;
        provider_factory.changeProviderResource(total_cpu,total_mem,total_storage,true);
    }
}
contract ProviderFactory is IProviderFactory,ReentrancyGuard {
    constructor (address _admin,address _order_factory,address _auditor_factory){
        admin = _admin;
        order_factory = _order_factory;
        auditor_factory = _auditor_factory;
    }
    uint256 constant div = 10;
    uint256 constant public MIN_VALUE_TO_BE_PROVIDER = 0 ether;
    uint256 public total_cpu;
    uint256 public total_mem;
    uint256 public total_storage;
    uint256 public total_used_cpu = 0;
    uint256 public total_used_mem = 0;
    uint256 public total_used_storage = 0;
    mapping(address => IProvider) public providers;
    mapping(address => uint256) public provider_pledge;
    IProvider[] providerArray;
    address public order_factory;
    address public admin;
    address public auditor_factory;
    struct providerInfo{
        address provider;
        address provider_owner;
        uint256 total_cpu;
        uint256 total_mem;
        uint256 total_sto;
        uint256 left_cpu;
        uint256 left_mem;
        uint256 left_sto;
        string info;
        bool is_active;
        address[] audits;
    }
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
    function createNewProvider(uint256 cpu_count, uint256 mem_count, uint256 storage_count,string memory provider_info)
    onlyNotProvider
    public payable returns(address){
        require(msg.value > MIN_VALUE_TO_BE_PROVIDER,"ProviderFactory: you must pledge money to be a provider");
        Provider provider_contract = new Provider(cpu_count,mem_count,storage_count,msg.sender,provider_info);
        total_cpu = total_cpu + cpu_count;
        total_mem = total_mem + mem_count;
        total_storage = total_storage + storage_count;
        providerArray.push(provider_contract);
        providers[msg.sender] = provider_contract;
        provider_pledge[msg.sender] = msg.value;
        return address(provider_contract);
    }
    function closeProvider()public onlyProvider{
        (uint256 temp_total_cpu,uint256 temp_total_mem,uint256 temp_total_sto) = providers[msg.sender].getTotalResource();
        (uint256 temp_left_cpu,uint256 temp_left_mem,uint256 temp_left_sto) = providers[msg.sender].getLeftResource();
        require(temp_left_cpu == temp_total_cpu);
        require(temp_left_mem == temp_total_mem);
        require(temp_left_sto == temp_total_sto);
        providers[msg.sender].changeActive(false);
        total_cpu = total_cpu - temp_total_cpu;
        total_mem = total_mem - temp_total_mem;
        total_storage = total_storage - temp_total_sto;
        payable(msg.sender).transfer(provider_pledge[msg.sender]);
    }
    function reOpenProvider()public payable onlyProvider{
        require(msg.value > MIN_VALUE_TO_BE_PROVIDER);
        providers[msg.sender].changeActive(true);
    }
    function changeOrderFactory(address new_order_factory) public onlyAdmin{
        require(new_order_factory != address(0));
        order_factory = new_order_factory;
    }
    function changeAdmin(address new_admin) public onlyAdmin{
        require(admin != address(0));
        admin = new_admin;
    }
    function getProvideContract(address account) external override view returns(address){
        return address(providers[account]);
    }
    function getProvideResource(address account) external override view returns(uint256,uint256,uint256){
        require(account != address(0));
        require(address(providers[IProvider(account).owner()]) == account,"ProviderFactory : this provider doesnt exist");
        return IProvider(account).getLeftResource();
    }
    function getProvideTotalResource(address account) external override view returns(uint256,uint256,uint256){
        require(account != address(0));
        require(address(providers[IProvider(account).owner()]) == account,"ProviderFactory : this provider doesnt exist");
        return IProvider(account).getTotalResource();
    }
    function changeProviderResource(uint256 cpu_count, uint256 mem_count, uint256 storage_count, bool add) external onlyProvider override{
        if (add){
            total_cpu = total_cpu + cpu_count;
            total_mem = total_mem + mem_count;
            total_storage = total_storage + storage_count;
        }else{
            total_cpu = total_cpu - cpu_count;
            total_mem = total_mem - mem_count;
            total_storage = total_storage - storage_count;
        }
    }
    function changeProviderUsedResource(uint256 cpu_count, uint256 mem_count, uint256 storage_count, bool add) external override onlyProvider{
        if (add){
            total_used_cpu = total_used_cpu + cpu_count;
            total_used_mem = total_used_mem + mem_count;
            total_used_storage = total_used_storage + storage_count;
        }else{
            total_used_cpu = total_used_cpu - cpu_count;
            total_used_mem = total_used_mem - mem_count;
            total_used_storage = total_used_storage - storage_count;
        }
    }
    function consumeResource(address account,uint256 cpu_count, uint256 mem_count, uint256 storage_count)external override nonReentrant{
        require(IOrderFactory(order_factory).checkIsOrder(msg.sender) == 1,"ProviderFactory : not order user");
        require(account != address(0));
        require(address(providers[IProvider(account).owner()]) == account);
        IProvider(account).consumeResource(cpu_count,mem_count,storage_count);
    }
    function recoverResource(address account,uint256 cpu_count, uint256 mem_count, uint256 storage_count)external override nonReentrant{
        require(IOrderFactory(order_factory).checkIsOrder(msg.sender)==1,"ProviderFactory : not order user");
        require(account != address(0));
        require(address(providers[IProvider(account).owner()]) == account);
        IProvider(account).recoverResource(cpu_count,mem_count,storage_count);
    }
    function getProviderInfoLength() public view returns(uint256){
        return providerArray.length;
    }
    function getProviderInfo(uint256 start,uint256 limit) public view returns(providerInfo[] memory){
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
        providerInfo[] memory _providerInfo =new providerInfo[](_count);
        for(uint256 i = 0;i < _count;i++){
            (uint256 temp_total_cpu,uint256 temp_total_mem,uint256 temp_total_sto) = providerArray[start+i].getTotalResource();
            (uint256 temp_left_cpu,uint256 temp_left_mem,uint256 temp_left_sto) = providerArray[start+i].getLeftResource();
            _providerInfo[i].total_cpu = temp_total_cpu;
            _providerInfo[i].total_mem = temp_total_mem;
            _providerInfo[i].total_sto = temp_total_sto;
            _providerInfo[i].left_cpu = temp_left_cpu;
            _providerInfo[i].left_mem = temp_left_mem;
            _providerInfo[i].left_sto = temp_left_sto;
            _providerInfo[i].provider = address(providerArray[start+i]);
            _providerInfo[i].provider_owner = providerArray[start+i].owner();
            _providerInfo[i].info = providerArray[start+i].info();
            _providerInfo[i].is_active = providerArray[start+i].isActive();
            _providerInfo[i].audits = IAuditorFactory(auditor_factory).getProviderAuditors(_providerInfo[i].provider);
        }
        return _providerInfo;
    }
}
