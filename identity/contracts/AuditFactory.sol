// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./ReentrancyGuard.sol";
import "./InterfaceAuditor.sol";

contract Auditor is IAuditor,ReentrancyGuard{
    address public override admin;
    IAuditorFactory public auditor_factory;
    mapping(address=>providerState) public provider_state;
    mapping(address=>string) provider_json;
    constructor(address _admin){
        admin = _admin;
        auditor_factory = IAuditorFactory(msg.sender);
    }
    modifier onlyAdmin(){
        require(msg.sender == admin,"Auditor:only admin can use this function");
        _;
    }
    function uploadProviderState(address provider,string memory json_check) external onlyAdmin nonReentrant{
        providerState _state = providerState.checkFail;
        string memory empty_string = "{}";
        if(keccak256(abi.encodePacked(json_check)) != keccak256(abi.encodePacked(empty_string))){
            _state = providerState.checked;
        }
        provider_state[provider] = _state;
        provider_json[provider] = json_check;
        auditor_factory.reportProviderState(provider,_state);
    }
    function getProviderCheckJson(address provider) external view returns(string memory){
        if(provider_state[provider] == providerState.unSet){
            return "{}";
        }else{
            return provider_json[provider];
        }
    }
}



contract AuditorFactory is IAuditorFactory,ReentrancyGuard {
    address public admin;
    uint256 constant public MIN_VALUE_TO_BE_AUDITOR = 0 ether;
    mapping(address=>uint256) public auditor_pledge;
    mapping(address=>IAuditor)public auditors;
    mapping(address=>mapping(address=>providerState)) public provider_auditor_state;
    mapping(address=>address[]) public provider_auditor;

    constructor (address _admin){
        admin = _admin;
    }
    modifier onlyNotAuditor(){
        require(auditors[msg.sender] == IAuditor(address(0)),"AuditorFactory:only not auditor can use this function");
        _;
    }
    modifier onlyAuditor(){
        require(auditors[IAuditor(msg.sender).admin()] != IAuditor(address(0)));
        _;
    }
    modifier onlyAdmin() {
        require(msg.sender == admin, "admin  only");
        _;
    }
    function createAuditor()external payable onlyNotAuditor nonReentrant returns(address){
        require(msg.value >MIN_VALUE_TO_BE_AUDITOR,"AuditorFactory:you must pledge money to be a auditor");
        Auditor auditor_contract = new Auditor{salt:keccak256(abi.encodePacked(msg.sender,"auditor"))}(msg.sender);
        auditors[msg.sender] = auditor_contract;
        auditor_pledge[msg.sender] = msg.value;
        return address(auditor_contract);
    }
    function changeAdmin(address new_admin) public onlyAdmin{
        require(admin != address(0));
        admin = new_admin;
    }
    function reportProviderState(address provider, providerState state) external onlyAuditor nonReentrant override {
        if(provider_auditor_state[provider][msg.sender] == providerState.unSet){
            provider_auditor[provider].push(msg.sender);
        }
        require(state == providerState.checkFail || state == providerState.checked);
        provider_auditor_state[provider][msg.sender] = state;
    }
    function getProviderAuditors(address provider) external view override returns(address[] memory){
        uint256 _count = 0;
        for(uint256 i = 0;i < provider_auditor[provider].length;i++){
            if(provider_auditor_state[provider][provider_auditor[provider][i]] == providerState.checked){
                _count = _count+1;
            }
        }
        uint256 index = 0;
        address[] memory _provider_auditors = new address[](_count);
        for(uint256 i = 0;i < provider_auditor[provider].length;i++){
            if(provider_auditor_state[provider][provider_auditor[provider][i]] == providerState.checked){
                _provider_auditors[index] = provider_auditor[provider][i];
                index = index+1;
            }
            if (index == _count){
                break;
            }
        }
        return _provider_auditors;
    }
    function getProviderJson(address auditor,address provider) external view returns(string memory){
        require(auditor != address(0));
        return IAuditor(auditor).getProviderCheckJson(provider);
    }
}
