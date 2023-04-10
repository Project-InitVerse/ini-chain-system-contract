import type {ValidatorFactory,Validator} from "../../src/types";
const {ethers,network}=require('hardhat')
import {expect} from 'chai';
import { BigNumber } from "ethers";
import exp from "constants";


describe('Validator test',function(){
  let validator1:any,validator2:any,admin_change:any,admin:any;
  let whiteList:any;
  let zeroAddress = '0x0000000000000000000000000000000000000000';
  beforeEach(async function (){
    [validator1,validator2,admin,admin_change] = await ethers.getSigners();
    console.log(validator1.address)
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

})
