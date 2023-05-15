import type {ValidatorFactory,Validator,MockProviderFactory} from "../../src/types";
const {ethers,network}=require('hardhat')
import {expect} from 'chai';
import { BigNumber } from "ethers";
import exp from "constants";


describe('Validator test',function(){
  let validator1:any,validator2:any,admin_change:any,admin:any,punish_address:any,provider:any;
  let whiteList:any;
  let zeroAddress = '0x0000000000000000000000000000000000000000';

  beforeEach(async function (){
    [validator1,validator2,admin,admin_change,punish_address,provider] = await ethers.getSigners();
    //console.log(validator1.address)
    let whiteListTemp = await ethers.getSigners();

    whiteList = []
    for(let i = 11;i<16;i++){
      whiteList.push(whiteListTemp[i].address);
    }
    this.valFactory = await (await ethers.getContractFactory('ValidatorFactory')).deploy()

  })
  it('initialize check',async function (){
    await this.valFactory.initialize(whiteList,admin.address);

    expect(await this.valFactory.current_validator_count()).to.equal(5);
    let block = await ethers.provider.getBlock("latest");
    for(let i = 0;i < 5;i++){
      let provider = await ethers.getContractAt('Validator',await this.valFactory.owner_validator(whiteList[i]))
      expect(await provider.last_punish_time()).to.equal(0);
      expect(await provider.create_time()).to.equal(block.timestamp);
      expect(await provider.punish_start_time()).to.equal(0);
      expect(await provider.pledge_amount()).to.equal(0);
      expect(await provider.state()).to.equal(3)
    }
    expect(await this.valFactory.max_validator_count()).to.equal(61);
    expect(await this.valFactory.validator_pledgeAmount()).to.equal(ethers.utils.parseEther('50000'));
    expect(await this.valFactory.team_percent()).to.equal(400);
    expect(await this.valFactory.validator_percent()).to.equal(1000);
    expect(await this.valFactory.all_percent()).to.equal(10000);
    expect(await this.valFactory.validator_lock_time()).to.equal(365*24*60*60);
    expect(await this.valFactory.validator_punish_start_limit()).to.equal(48*60*60);
    expect(await this.valFactory.validator_punish_interval()).to.equal(1*60*60);
    await expect(this.valFactory.initialize(whiteList,admin.address)).to.be.revertedWith('ValidatorFactory:this contract has been initialized');
  })
  it('new validator',async function(){
    await this.valFactory.initialize(whiteList,admin.address);
    await expect(this.valFactory.connect(admin_change).changeValidatorMinPledgeAmount(ethers.utils.parseEther("1"))).to.be.revertedWith('ValidatorFactory:only admin use this function');
    await this.valFactory.connect(admin).changeValidatorMinPledgeAmount(ethers.utils.parseEther("1"));
    expect(await this.valFactory.current_validator_count()).to.equal(5);
    await expect(this.valFactory.connect(validator1).createValidator()).to.be.revertedWith('ValidatorFactory: not enough value to be a validator');
    await this.valFactory.connect(validator1).createValidator({value:ethers.utils.parseEther("1")});
    expect(await this.valFactory.getAllValidatorLength()).to.equal(6);
    expect(await this.valFactory.current_validator_count()).to.equal(5);
  })
  it('to be new validator',async function(){
    await this.valFactory.initialize(whiteList,admin.address);
    await this.valFactory.connect(admin).changeValidatorMinPledgeAmount(ethers.utils.parseEther("1"));
    await this.valFactory.connect(validator1).createValidator({value:ethers.utils.parseEther("1")});
    await expect(this.valFactory.connect(admin_change).changeValidatorState(validator1.address,3)).to.be.revertedWith('ValidatorFactory:only admin use this function');
    await this.valFactory.connect(admin).changeValidatorState(validator1.address,3);
    expect(await this.valFactory.current_validator_count()).to.equal(6);
  })
  it('try punish',async function (){
    await this.valFactory.initialize(whiteList,admin.address);
    await this.valFactory.connect(admin).changeValidatorMinPledgeAmount(ethers.utils.parseEther("1"));
    await this.valFactory.connect(validator1).createValidator({value:ethers.utils.parseEther("1")});
    await this.valFactory.connect(admin).changeValidatorState(validator1.address,3);
    console.log(await this.valFactory.getAllPunishValidator());
    await this.valFactory.tryPunish(validator1.address);
    console.log(await this.valFactory.getAllPunishValidator());
    let a = await this.valFactory.getAllPunishValidator();
    expect(a.length).to.equal(1);
    expect(a[0]).to.equal(validator1.address);
  })
  it('punish ',async function (){
    await this.valFactory.initialize(whiteList,admin.address);
    await this.valFactory.connect(admin).changePunishAddress(punish_address.address);
    await this.valFactory.connect(admin).changeValidatorMinPledgeAmount(ethers.utils.parseEther("1"));
    await this.valFactory.connect(validator1).createValidator({value:ethers.utils.parseEther("1")});
    await this.valFactory.connect(admin).changeValidatorState(validator1.address,3);
    await this.valFactory.tryPunish(validator1.address);
    let punishBlock = await ethers.provider.getBlock("latest");
    let punish_start_balance = await ethers.provider.getBalance(punish_address.address);

    let validator1_contract = await ethers.getContractAt('Validator',await this.valFactory.owner_validator(validator1.address))
    expect(await validator1_contract.punish_start_time()).to.equal(punishBlock.timestamp);
    expect(await validator1_contract.state()).to.equal(1);
    await network.provider.request({
      method: "evm_setNextBlockTimestamp",
      params: [punishBlock.timestamp+48*3600+30],
    });
    await this.valFactory.tryPunish(zeroAddress);
    expect(await validator1_contract.state()).to.equal(2);
    let punish_balance = await ethers.provider.getBalance(punish_address.address);
    expect(punish_balance.sub(punish_start_balance)).to.equal(ethers.utils.parseEther('0.01'));
    await this.valFactory.tryPunish(zeroAddress);
    expect(await validator1_contract.state()).to.equal(2);
    punish_balance = await ethers.provider.getBalance(punish_address.address);
    expect(punish_balance.sub(punish_start_balance)).to.equal(ethers.utils.parseEther('0.01'));
    expect(await validator1_contract.pledge_amount()).to.equal(ethers.utils.parseEther("0.99"))
    let block_last = await ethers.provider.getBlock("latest");
    await network.provider.request({
      method: "evm_setNextBlockTimestamp",
      params: [block_last.timestamp+1*3600+50],
    });
    await this.valFactory.tryPunish(zeroAddress);
    expect(await validator1_contract.state()).to.equal(2);
    punish_balance = await ethers.provider.getBalance(punish_address.address);
    expect(punish_balance.sub(punish_start_balance)).to.equal(ethers.utils.parseEther('0.02'));
    expect(await validator1_contract.pledge_amount()).to.equal(ethers.utils.parseEther("0.98"))
    await expect(this.valFactory.connect(validator2).MarginCalls({value:ethers.utils.parseEther("1")})).to.be.revertedWith('ValidatorFactory : you account is not a validator');
    await expect(this.valFactory.connect(validator1).MarginCalls({value:ethers.utils.parseEther("1")})).to.be.revertedWith('posMargin must less than max validator pledge amount')
    await this.valFactory.connect(validator1).MarginCalls({value:ethers.utils.parseEther("0.01")});
    expect(await validator1_contract.pledge_amount()).to.equal(ethers.utils.parseEther("0.99"))
  })
  it('challenge',async function(){
    await this.valFactory.initialize(whiteList,admin.address);
    this.provider_factory = await (await ethers.getContractFactory('MockProviderFactory')).deploy();

    await this.valFactory.connect(admin).setProviderFactory(this.provider_factory .address);
    await this.valFactory.challengeProvider(provider.address,10,"www.baidu.com");
    let index = await this.valFactory.provider_index(provider.address);
    expect(await this.valFactory.provider_index(provider.address)).to.equal(1);
    let challenge_info = await this.valFactory.provider_challenge_info(provider.address,(index-1)%10);
    expect(challenge_info.state).to.equal(1);
    expect(challenge_info.url).to.equal("www.baidu.com");
    await this.valFactory.challengeFinish(provider.address,20,3,3,2);
    expect(await this.valFactory.provider_index(provider.address)).to.equal(1);
    challenge_info = await this.valFactory.provider_challenge_info(provider.address,(index-1)%10);
    expect(challenge_info.state).to.equal(2);
  })
})
