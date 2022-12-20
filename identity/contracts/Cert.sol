// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
enum CertState {
    Deleted,Using
}
interface ICert{
    function user_cert_state(address user,string memory cert) external view returns(CertState);
}
contract Cert is ICert{
    mapping(address=>mapping(string=>CertState)) public override user_cert_state;
    mapping(address=>string[])user_cert;
    mapping(string=>address) public cert_user;

    function upData(string memory new_cert,CertState _state) public{
        if(cert_user[new_cert]!= address(0)){
            require(msg.sender == cert_user[new_cert]);
        }
        user_cert_state[msg.sender][new_cert] = _state;
        if (cert_user[new_cert] == address(0)){
            user_cert[msg.sender].push(new_cert);
        }
        cert_user[new_cert] = msg.sender;
    }
    function getAllUserCert(address user)public view returns(string[] memory){
        return user_cert[user];
    }
    function getUserStateCert(address user,CertState _state)public view returns(string[] memory){
        uint256 _count = 0;
        for(uint256 i = 0;i < user_cert[user].length;i++){
            if(user_cert_state[user][user_cert[user][i]] == _state){
                _count++;
            }
        }
        string[] memory ret = new string[](_count);
        uint256 _index = 0;
        for(uint256 i = 0;i < user_cert[user].length;i++){
            if(user_cert_state[user][user_cert[user][i]] == _state){
                ret[_index] = user_cert[user][i];
                _index++;
            }
            if(_index == _count){
                break;
            }
        }
        return ret;
    }
}
