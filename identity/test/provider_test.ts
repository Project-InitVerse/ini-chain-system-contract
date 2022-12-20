import { BigNumber } from "ethers";

const {ethers} = require('hardhat')
import chai, { expect } from "chai";
import type {MockOrder,AuditorFactory,ProviderFactory,Provider} from "../types";

describe('provider test',function(){
  let factory_admin:any,provider_1:any,provider_2:any,cus:any;
  let zero_addr: string = '0x0000000000000000000000000000000000000000'
  beforeEach(async function(){
    [factory_admin,provider_1,provider_2,cus] = await ethers.getSigners();
    this.orderFactory = await (await ethers.getContractFactory('MockOrder')).deploy();
    this.adminFactory = await (await ethers.getContractFactory('AuditorFactory', factory_admin)).deploy(factory_admin.address);
    this.providerFactory = await (await ethers.getContractFactory('ProviderFactory',factory_admin)).deploy(factory_admin.address,
      this.orderFactory.address,this.adminFactory.address);
  })
  it('init',async function(){
    expect(await this.providerFactory.providers(provider_1.address)).to.equal(zero_addr);
    expect(await this.providerFactory.providers(provider_2.address)).to.equal(zero_addr);
    expect(await this.providerFactory.total_cpu()).to.equal(0);
    expect(await this.providerFactory.total_mem()).to.equal(0);
    expect(await this.providerFactory.total_storage()).to.equal(0);
    expect(await this.providerFactory.total_used_cpu()).to.equal(0);
    expect(await this.providerFactory.total_used_mem()).to.equal(0);
    expect(await this.providerFactory.total_used_storage()).to.equal(0);
    //await expect( this.providerFactory.getProvideTotalResource(provider_1.address)).to.be.revertedWith('ProviderFactory : this provider doesnt exist')
    //await expect( this.providerFactory.getProvideResource(provider_1.address)).to.be.revertedWith('ProviderFactory : this provider doesnt exist')
  })
  it("create provider", async function() {
    await expect(this.providerFactory.connect(provider_1).createNewProvider(3,6,9,"{}")).to.be.revertedWith('ProviderFactory: you must pledge money to be a provider');
    await this.providerFactory.connect(provider_1).createNewProvider(3,6,9,"{}",{value:ethers.utils.parseEther("1")});
    await expect(this.providerFactory.connect(provider_1).createNewProvider(3,6,9,"{}")).to.be.revertedWith('ProviderFactory: only not provider can use this function');
    let provider_contract1 = await this.providerFactory.providers(provider_1.address);
    expect(await this.providerFactory.total_cpu()).to.equal(3);
    expect(await this.providerFactory.total_mem()).to.equal(6);
    expect(await this.providerFactory.total_storage()).to.equal(9);
    expect(await this.providerFactory.total_used_cpu()).to.equal(0);
    expect(await this.providerFactory.total_used_mem()).to.equal(0);
    expect(await this.providerFactory.total_used_storage()).to.equal(0);
    expect(await this.providerFactory.providers(provider_2.address)).to.equal(zero_addr);
    await this.providerFactory.connect(provider_2).createNewProvider(9,6,3,"{}",{value:ethers.utils.parseEther("1")});
    expect(await this.providerFactory.providers(provider_2.address)).to.not.equal(zero_addr);
    let provider_contract2 = await this.providerFactory.providers(provider_2.address);
    expect(await this.providerFactory.total_cpu()).to.equal(12);
    expect(await this.providerFactory.total_mem()).to.equal(12);
    expect(await this.providerFactory.total_storage()).to.equal(12);
    expect(await this.providerFactory.total_used_cpu()).to.equal(0);
    expect(await this.providerFactory.total_used_mem()).to.equal(0);
    expect(await this.providerFactory.total_used_storage()).to.equal(0);
  });
  it("consume resource", async function() {

    await this.providerFactory.connect(provider_1).createNewProvider(3,6,9,"{}",{value:ethers.utils.parseEther("1")});
    await this.providerFactory.connect(provider_2).createNewProvider(9,6,3,"{}",{value:ethers.utils.parseEther("1")});
    let provider_contract_1 = await this.providerFactory.providers(provider_1.address);
    let provider_contract_2 = await this.providerFactory.providers(provider_2.address);
    await expect(this.providerFactory.connect(cus).consumeResource(provider_contract_1,2,1,1)).to.be.revertedWith('ProviderFactory : not order user');
    await this.orderFactory.connect(cus).set()
    expect(await this.orderFactory.cc(cus.address)).to.equal(1)
    await this.providerFactory.connect(cus).consumeResource(provider_contract_1,2,1,1);
    expect(await this.providerFactory.total_cpu()).to.equal(12);
    expect(await this.providerFactory.total_mem()).to.equal(12);
    expect(await this.providerFactory.total_storage()).to.equal(12);
    expect(await this.providerFactory.total_used_cpu()).to.equal(2);
    expect(await this.providerFactory.total_used_mem()).to.equal(1);
    expect(await this.providerFactory.total_used_storage()).to.equal(1);
    let [x,y,z] = await this.providerFactory.getProvideResource(provider_contract_1)
    expect(x).to.equal(BigNumber.from(1));
    expect(y).to.equal(BigNumber.from(5));
    expect(z).to.equal(BigNumber.from(8));
    [x,y,z] = await this.providerFactory.getProvideTotalResource(provider_contract_1)
    expect(x).to.equal(BigNumber.from(3));
    expect(y).to.equal(BigNumber.from(6));
    expect(z).to.equal(BigNumber.from(9));
    await expect(this.providerFactory.connect(cus).consumeResource(provider_contract_1,5,1,1)).to.be.revertedWith('Provider:cpu is not enough');
    await expect(this.providerFactory.connect(cus).consumeResource(provider_contract_1,1,6,1)).to.be.revertedWith('Provider:mem is not enough');
    await expect(this.providerFactory.connect(cus).consumeResource(provider_contract_1,1,1,10)).to.be.revertedWith('Provider:storage is not enough');
  });
  it("recover Resource", async function() {
    await this.providerFactory.connect(provider_1).createNewProvider(3,6,9,"{}",{value:ethers.utils.parseEther("1")});
    await this.providerFactory.connect(provider_2).createNewProvider(9,6,3,"{}",{value:ethers.utils.parseEther("1")});
    let provider_contract_1 = await this.providerFactory.providers(provider_1.address);
    let provider_contract_2 = await this.providerFactory.providers(provider_2.address);
    await this.orderFactory.connect(cus).set()
    await this.providerFactory.connect(cus).consumeResource(provider_contract_1,2,1,1);
    await expect(this.providerFactory.connect(factory_admin).recoverResource(provider_contract_1,2,1,1)).to.be.revertedWith('ProviderFactory : not order user');
    await this.providerFactory.connect(cus).recoverResource(provider_contract_1,2,1,1);
    expect(await this.providerFactory.total_cpu()).to.equal(12);
    expect(await this.providerFactory.total_mem()).to.equal(12);
    expect(await this.providerFactory.total_storage()).to.equal(12);
    expect(await this.providerFactory.total_used_cpu()).to.equal(0);
    expect(await this.providerFactory.total_used_mem()).to.equal(0);
    expect(await this.providerFactory.total_used_storage()).to.equal(0);
    let [x,y,z] = await this.providerFactory.getProvideResource(provider_contract_1)
    expect(x).to.equal(BigNumber.from(3));
    expect(y).to.equal(BigNumber.from(6));
    expect(z).to.equal(BigNumber.from(9));
    [x,y,z] = await this.providerFactory.getProvideTotalResource(provider_contract_1)
    expect(x).to.equal(BigNumber.from(3));
    expect(y).to.equal(BigNumber.from(6));
    expect(z).to.equal(BigNumber.from(9));
    await this.providerFactory.connect(cus).consumeResource(provider_contract_1,2,1,1);
    await this.providerFactory.connect(cus).recoverResource(provider_contract_1,3,1,1);
    [x,y,z] = await this.providerFactory.getProvideResource(provider_contract_1)
    expect(x).to.equal(BigNumber.from(0));
    expect(y).to.equal(BigNumber.from(0));
    expect(z).to.equal(BigNumber.from(0));
    [x,y,z] = await this.providerFactory.getProvideTotalResource(provider_contract_1)
    expect(x).to.equal(BigNumber.from(2));
    expect(y).to.equal(BigNumber.from(1));
    expect(z).to.equal(BigNumber.from(1));
    expect(await this.providerFactory.total_cpu()).to.equal(11);
    expect(await this.providerFactory.total_mem()).to.equal(7);
    expect(await this.providerFactory.total_storage()).to.equal(4);
    expect(await this.providerFactory.total_used_cpu()).to.equal(2);
    expect(await this.providerFactory.total_used_mem()).to.equal(1);
    expect(await this.providerFactory.total_used_storage()).to.equal(1);

  });
  it("Provider Length", async function() {
    expect(await  this.providerFactory.getProviderInfoLength()).to.equal(0)
    await this.providerFactory.connect(provider_1).createNewProvider(3,6,9,"{}",{value:ethers.utils.parseEther("1")});
    expect(await  this.providerFactory.getProviderInfoLength()).to.equal(1)
    await this.providerFactory.connect(provider_2).createNewProvider(9,6,3,"{}",{value:ethers.utils.parseEther("1")});
    expect(await  this.providerFactory.getProviderInfoLength()).to.equal(2)
  });
  it("Provider update",async function (){
    await this.providerFactory.connect(provider_1).createNewProvider(3,6,9,"{}",{value:ethers.utils.parseEther("1")});
    await this.providerFactory.connect(provider_2).createNewProvider(9,6,3,"{}",{value:ethers.utils.parseEther("1")});

    let provider_contract_1 = await this.providerFactory.providers(provider_1.address);
    await this.orderFactory.connect(cus).set()
    await this.providerFactory.connect(cus).consumeResource(provider_contract_1,2,1,1);
    let provider_c = <Provider>await ethers.getContractAt("Provider",provider_contract_1);
    await expect(provider_c.connect(factory_admin).updateResource(0,1,1)).to.be.revertedWith('Provider:only owner can use this function');
    await provider_c.connect(provider_1).updateResource(0,1,1);
    expect(await this.providerFactory.total_cpu()).to.equal(11);
    expect(await this.providerFactory.total_mem()).to.equal(8);
    expect(await this.providerFactory.total_storage()).to.equal(5);
    expect(await this.providerFactory.total_used_cpu()).to.equal(2);
    expect(await this.providerFactory.total_used_mem()).to.equal(1);
    expect(await this.providerFactory.total_used_storage()).to.equal(1);
    let [x,y,z] = await this.providerFactory.getProvideResource(provider_contract_1)
    expect(x).to.equal(BigNumber.from(0));
    expect(y).to.equal(BigNumber.from(1));
    expect(z).to.equal(BigNumber.from(1));
    [x,y,z] = await this.providerFactory.getProvideTotalResource(provider_contract_1)
    expect(x).to.equal(BigNumber.from(2));
    expect(y).to.equal(BigNumber.from(2));
    expect(z).to.equal(BigNumber.from(2));
  })
})
