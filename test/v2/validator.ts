import type { ValidatorFactory, Validator, MockProviderFactory,Mockown } from "../../src/types";

const { ethers, network } = require("hardhat");
import { expect } from "chai";
import { BigNumber } from "ethers";
import exp from "constants";


describe("Validator test", function() {
  let validator1: any, validator2: any, admin_change: any, admin: any, punish_address: any, provider: any;
  let whiteList: any;
  let zeroAddress = "0x0000000000000000000000000000000000000000";
  let block: any;
  beforeEach(async function() {
    [validator1, validator2, admin, admin_change, punish_address, provider] = await ethers.getSigners();
    //console.log(validator1.address)
    let whiteListTemp = await ethers.getSigners();

    whiteList = [];
    for (let i = 11; i < 16; i++) {
      whiteList.push(whiteListTemp[i].address);
    }
    this.valFactory = await (await ethers.getContractFactory("ValidatorFactory")).deploy();
    this.punishItem = await (await ethers.getContractFactory("PunishContract", admin)).deploy();
    await this.valFactory.initialize(whiteList, admin.address);
    block = await ethers.provider.getBlock("latest");
    await this.punishItem.setFactoryAddr(this.valFactory.address);
    await this.valFactory.connect(admin).changeValidatorPunishItemAddr(this.punishItem.address);
    this.mockown = await (await ethers.getContractFactory("Mockown")).deploy();
    await this.mockown.setfactory(this.valFactory.address);
  });
  it("initialize check", async function() {
    expect(await this.valFactory.current_validator_count()).to.equal(5);
    for (let i = 0; i < 5; i++) {
      let provider = await ethers.getContractAt("Validator", await this.valFactory.owner_validator(whiteList[i]));
      expect(await provider.last_punish_time()).to.equal(0);
      expect(await provider.create_time()).to.equal(block.timestamp);
      expect(await provider.punish_start_time()).to.equal(0);
      expect(await provider.pledge_amount()).to.equal(0);
      expect(await provider.state()).to.equal(3);
    }
    expect(await this.valFactory.max_validator_count()).to.equal(61);
    expect(await this.valFactory.validator_pledgeAmount()).to.equal(ethers.utils.parseEther("50000"));
    expect(await this.valFactory.team_percent()).to.equal(400);
    expect(await this.valFactory.validator_percent()).to.equal(1000);
    expect(await this.valFactory.all_percent()).to.equal(10000);
    expect(await this.valFactory.validator_lock_time()).to.equal(365 * 24 * 60 * 60);
    expect(await this.valFactory.validator_punish_start_limit()).to.equal(48 * 60 * 60);
    expect(await this.valFactory.validator_punish_interval()).to.equal(1 * 60 * 60);
    await expect(this.valFactory.initialize(whiteList, admin.address)).to.be.revertedWith("ValidatorFactory:this contract has been initialized");
  });
  it("new validator", async function() {
    await expect(this.valFactory.connect(admin_change).changeValidatorMinPledgeAmount(ethers.utils.parseEther("1"))).to.be.revertedWith("ValidatorFactory:only admin use this function");
    await this.valFactory.connect(admin).changeValidatorMinPledgeAmount(ethers.utils.parseEther("1"));
    expect(await this.valFactory.current_validator_count()).to.equal(5);
    await expect(this.valFactory.connect(validator1).createValidator()).to.be.revertedWith("ValidatorFactory: not enough value to be a validator");
    await this.valFactory.connect(validator1).createValidator({ value: ethers.utils.parseEther("1") });
    expect(await this.valFactory.getAllValidatorLength()).to.equal(6);
    expect(await this.valFactory.current_validator_count()).to.equal(5);
  });
  it("to be new validator", async function() {
    await this.valFactory.connect(admin).changeValidatorMinPledgeAmount(ethers.utils.parseEther("1"));
    await this.valFactory.connect(validator1).createValidator({ value: ethers.utils.parseEther("1") });
    await expect(this.valFactory.connect(admin_change).changeValidatorState(validator1.address, 3)).to.be.revertedWith("ValidatorFactory:only admin use this function");
    await this.valFactory.connect(admin).changeValidatorState(validator1.address, 3);
    expect(await this.valFactory.current_validator_count()).to.equal(6);
  });
  it("try punish", async function() {
    await this.valFactory.connect(admin).changeValidatorMinPledgeAmount(ethers.utils.parseEther("1"));
    await this.valFactory.connect(validator1).createValidator({ value: ethers.utils.parseEther("1") });
    await this.valFactory.connect(admin).changeValidatorState(validator1.address, 3);
    console.log(await this.valFactory.getAllPunishValidator());
    await this.valFactory.tryPunish(validator1.address);
    console.log(await this.valFactory.getAllPunishValidator());
    let a = await this.valFactory.getAllPunishValidator();
    expect(a.length).to.equal(1);
    expect(a[0]).to.equal(validator1.address);
  });
  it("punish ", async function() {
    await this.valFactory.connect(admin).changePunishAddress(punish_address.address);
    await this.valFactory.connect(admin).changeValidatorMinPledgeAmount(ethers.utils.parseEther("1"));
    await this.valFactory.connect(validator1).createValidator({ value: ethers.utils.parseEther("1") });
    await this.valFactory.connect(admin).changeValidatorState(validator1.address, 3);
    await this.valFactory.tryPunish(validator1.address);
    let punishBlock = await ethers.provider.getBlock("latest");
    let punish_start_balance = await ethers.provider.getBalance(punish_address.address);

    let validator1_contract = await ethers.getContractAt("Validator", await this.valFactory.owner_validator(validator1.address));
    expect(await validator1_contract.punish_start_time()).to.equal(punishBlock.timestamp);
    expect(await validator1_contract.state()).to.equal(1);
    await network.provider.request({
      method: "evm_setNextBlockTimestamp",
      params: [punishBlock.timestamp + 48 * 3600 + 30],
    });
    await this.valFactory.tryPunish(zeroAddress);
    expect(await validator1_contract.state()).to.equal(2);
    let punish_balance = await ethers.provider.getBalance(punish_address.address);
    expect(punish_balance.sub(punish_start_balance)).to.equal(ethers.utils.parseEther("0.01"));
    await this.valFactory.tryPunish(zeroAddress);
    expect(await validator1_contract.state()).to.equal(2);
    punish_balance = await ethers.provider.getBalance(punish_address.address);
    expect(punish_balance.sub(punish_start_balance)).to.equal(ethers.utils.parseEther("0.01"));
    expect(await validator1_contract.pledge_amount()).to.equal(ethers.utils.parseEther("0.99"));
    let block_last = await ethers.provider.getBlock("latest");
    expect(await this.punishItem.current_index()).to.equal(1);
    expect(await this.punishItem.getValidatorPunishLength(validator1.address)).to.equal(1);
    let punishInfo = await this.punishItem.index_punish_items(0);
    expect(punishInfo.punish_owner).to.equal(validator1.address);
    expect(punishInfo.punish_amount).to.equal(ethers.utils.parseEther("0.01"));
    expect(punishInfo.balance_left).to.equal(await validator1_contract.pledge_amount());
    await network.provider.request({
      method: "evm_setNextBlockTimestamp",
      params: [block_last.timestamp + 1 * 3600 + 50],
    });
    await this.valFactory.tryPunish(zeroAddress);
    expect(await validator1_contract.state()).to.equal(2);
    punish_balance = await ethers.provider.getBalance(punish_address.address);
    expect(punish_balance.sub(punish_start_balance)).to.equal(ethers.utils.parseEther("0.02"));
    expect(await validator1_contract.pledge_amount()).to.equal(ethers.utils.parseEther("0.98"));
    await expect(this.valFactory.connect(validator2).MarginCalls({ value: ethers.utils.parseEther("1") })).to.be.revertedWith("not val");
    await expect(this.valFactory.connect(validator1).MarginCalls({ value: ethers.utils.parseEther("1") })).to.be.revertedWith("posMargin<val pledge amount");
    await this.valFactory.connect(validator1).MarginCalls({ value: ethers.utils.parseEther("0.01") });
    expect(await validator1_contract.pledge_amount()).to.equal(ethers.utils.parseEther("0.99"));
    expect(await this.punishItem.current_index()).to.equal(2);
    expect(await this.punishItem.getValidatorPunishLength(validator1.address)).to.equal(2);
    punishInfo = await this.punishItem.index_punish_items(0);
    expect(punishInfo.punish_owner).to.equal(validator1.address);
    expect(punishInfo.punish_amount).to.equal(ethers.utils.parseEther("0.01"));
    expect(punishInfo.balance_left).to.equal(ethers.utils.parseEther("0.99"));
    punishInfo = await this.punishItem.index_punish_items(1);
    expect(punishInfo.punish_owner).to.equal(validator1.address);
    expect(punishInfo.punish_amount).to.equal(ethers.utils.parseEther("0.01"));
    expect(punishInfo.balance_left).to.equal(ethers.utils.parseEther("0.98"));
  });
  it("punish all", async function() {
    await this.valFactory.connect(admin).changePunishAddress(punish_address.address);
    await this.valFactory.connect(admin).changeValidatorMinPledgeAmount(ethers.utils.parseEther("1"));
    await this.valFactory.connect(validator1).createValidator({ value: ethers.utils.parseEther("1") });
    await this.valFactory.connect(validator2).createValidator({ value: ethers.utils.parseEther("1") });
    await this.valFactory.connect(admin).changeValidatorState(validator1.address, 3);
    await this.valFactory.connect(admin).changeValidatorState(validator2.address, 3);
    expect(await this.valFactory.current_validator_count()).to.equal(7);
    let punishVals = await this.valFactory.getAllPunishValidator();
    expect(punishVals.length).to.equal(0);
    await this.valFactory.tryPunish(validator1.address);
    expect(await this.valFactory.current_validator_count()).to.equal(7);
    let punishBlock = await ethers.provider.getBlock("latest");
    punishVals = await this.valFactory.getAllPunishValidator();
    expect(punishVals.length).to.equal(1);
    await this.valFactory.connect(admin).changePunishPercent(1, 1);

    let punish_start_balance = await ethers.provider.getBalance(punish_address.address);

    let validator1_contract = await ethers.getContractAt("Validator", await this.valFactory.owner_validator(validator1.address));
    let validator2_contract = await ethers.getContractAt("Validator", await this.valFactory.owner_validator(validator2.address));
    expect(await validator1_contract.punish_start_time()).to.equal(punishBlock.timestamp);
    expect(await validator1_contract.state()).to.equal(1);
    await network.provider.request({
      method: "evm_setNextBlockTimestamp",
      params: [punishBlock.timestamp + 48 * 3600 + 30],
    });

    await this.valFactory.tryPunish(zeroAddress);
    expect(await this.valFactory.current_validator_count()).to.equal(6);
    expect(await validator1_contract.state()).to.equal(4);
    let punish_balance = await ethers.provider.getBalance(punish_address.address);
    expect(punish_balance.sub(punish_start_balance)).to.equal(ethers.utils.parseEther("1"));
    let punishInfo = await this.punishItem.index_punish_items(0);
    expect(await this.punishItem.current_index()).to.equal(1);
    expect(await this.punishItem.getValidatorPunishLength(validator1.address)).to.equal(1);
    expect(punishInfo.punish_owner).to.equal(validator1.address);
    expect(punishInfo.punish_amount).to.equal(ethers.utils.parseEther("1"));
    expect(punishInfo.balance_left).to.equal(await validator1_contract.pledge_amount());
    punishVals = await this.valFactory.getAllPunishValidator();
    expect(punishVals.length).to.equal(0);
    await this.valFactory.connect(validator1).MarginCalls( {value: ethers.utils.parseEther("0.5") })
    expect(await validator1_contract.state()).to.equal(3);
    await this.valFactory.tryPunish(validator1.address);
    expect(await validator1_contract.state()).to.equal(1);
    await this.valFactory.tryPunish(validator2.address);
    let count = 0;
    let punishAddrs = await this.valFactory.getAllPunishValidator();
    console.log(punishAddrs)
    for(let i=0;i < punishAddrs.length;i++){
      if(punishAddrs[i] == validator1.address || punishAddrs[i] == validator2.address){
        count = count+1;
      }
    }
    expect(count).to.equal(2);
    expect(await this.valFactory.current_validator_count()).to.equal(7);
    punishBlock = await ethers.provider.getBlock("latest");
    await network.provider.request({
      method: "evm_setNextBlockTimestamp",
      params: [punishBlock.timestamp + 48 * 3600 + 600],
    });
    punishVals = await this.valFactory.getAllPunishValidator();
    expect(punishVals.length).to.equal(2);
    await this.valFactory.tryPunish(zeroAddress);
    expect(await this.valFactory.current_validator_count()).to.equal(5);
    punishVals = await this.valFactory.getAllPunishValidator();
    expect(punishVals.length).to.equal(0);
    expect(await validator1_contract.state()).to.equal(4);
    expect(await validator2_contract.state()).to.equal(4);
    punish_balance = await ethers.provider.getBalance(punish_address.address);
    expect(punish_balance.sub(punish_start_balance)).to.equal(ethers.utils.parseEther("2.5"));
    expect(await this.punishItem.current_index()).to.equal(3);
    expect(await this.punishItem.getValidatorPunishLength(validator1.address)).to.equal(2);
    punishInfo = await this.punishItem.index_punish_items(0);
    expect(punishInfo.punish_owner).to.equal(validator1.address);
    expect(punishInfo.punish_amount).to.equal(ethers.utils.parseEther("1"));
    expect(punishInfo.balance_left).to.equal(await validator1_contract.pledge_amount());
    punishInfo = await this.punishItem.index_punish_items(1);
    expect(punishInfo.punish_owner).to.equal(validator2.address);
    expect(punishInfo.punish_amount).to.equal(ethers.utils.parseEther("1"));
    expect(punishInfo.balance_left).to.equal(await validator2_contract.pledge_amount());
    punishInfo = await this.punishItem.index_punish_items(2);
    expect(punishInfo.punish_owner).to.equal(validator1.address);
    expect(punishInfo.punish_amount).to.equal(ethers.utils.parseEther("0.5"));
    expect(punishInfo.balance_left).to.equal(await validator1_contract.pledge_amount());
  });
  it("challenge", async function() {
    this.provider_factory = await (await ethers.getContractFactory("MockProviderFactory")).deploy();

    await this.valFactory.connect(admin).setProviderFactory(this.provider_factory.address);
    let whiteListTemp = await ethers.getSigners();
    await this.valFactory.connect(whiteListTemp[11]).challengeProvider(provider.address, 10, "www.baidu.com");
    let index = await this.valFactory.provider_index(provider.address);
    expect(await this.valFactory.provider_index(provider.address)).to.equal(1);
    let challenge_info = await this.valFactory.provider_challenge_info(provider.address, (index - 1) % 10);
    expect(challenge_info.state).to.equal(1);
    expect(challenge_info.url).to.equal("www.baidu.com");
    await this.valFactory.connect(whiteListTemp[11]).challengeFinish(provider.address, 20, 3, 3, 2);
    expect(await this.valFactory.provider_index(provider.address)).to.equal(1);
    challenge_info = await this.valFactory.provider_challenge_info(provider.address, (index - 1) % 10);
    expect(challenge_info.state).to.equal(2);
  });
  it("fake owner",async function(){
    await this.valFactory.connect(admin).changeValidatorMinPledgeAmount(ethers.utils.parseEther("1"))
    expect(await this.valFactory.current_validator_count()).to.equal(5);
    await this.valFactory.connect(validator1).createValidator({ value: ethers.utils.parseEther("1") });
    await this.valFactory.connect(admin).changeValidatorState(validator1.address, 3);
    let validator1_contract = await ethers.getContractAt("Validator", await this.valFactory.owner_validator(validator1.address));
    await this.mockown.setOwner(validator1.address);
    expect(await this.valFactory.current_validator_count()).to.equal(6);
    await expect(this.mockown.mockAttack()).to.be.revertedWith("ValidatorFactory: only validator contract equal");
    expect(await this.valFactory.current_validator_count()).to.equal(6);
    await validator1_contract.testOwner();
    expect(await this.valFactory.current_validator_count()).to.equal(5);
  })
});
