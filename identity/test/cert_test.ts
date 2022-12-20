import type {Cert} from "../types";
const {ethers,network}= require('hardhat')
import {expect} from "chai";
import {BigNumber} from "ethers";

describe('auditor test',function(){
  let user1:any,user2:any;
  let zero_addr: string = '0x0000000000000000000000000000000000000000'
  beforeEach(async function(){
    [user1,user2] = await ethers.getSigners()
    this.Cert = await (await ethers.getContractFactory('Cert')).deploy();
  })
  it("all test", async function() {
    await this.Cert.connect(user1).upData("haha1",1)
    expect(await this.Cert.user_cert_state(user1.address,"haha1")).to.equal(1)
    await this.Cert.connect(user1).upData("haha1",0)
    expect(await this.Cert.user_cert_state(user1.address,"haha1")).to.equal(0)
    await this.Cert.connect(user1).upData("haha2",0)
    await this.Cert.connect(user1).upData("haha3",0)
    let c = await this.Cert.getUserStateCert(user1.address,0)
    let cx =await this.Cert.getUserStateCert(user1.address,1)
    expect(c.length).to.equal(3)
    expect(cx.length).to.equal(0)
    expect(c[0]).to.equal('haha1')
    expect(c[1]).to.equal('haha2')
    expect(c[2]).to.equal('haha3')
    await this.Cert.connect(user1).upData("haha1",1)
    await this.Cert.connect(user1).upData("haha2",0)
    await this.Cert.connect(user1).upData("haha3",1)
    c =await this.Cert.getUserStateCert(user1.address,0)
    cx = await this.Cert.getUserStateCert(user1.address,1)
    expect(c.length).to.equal(1)
    expect(cx.length).to.equal(2)
    expect(cx[0]).to.equal('haha1')
    expect(c[0]).to.equal('haha2')
    expect(cx[1]).to.equal('haha3')
    let b = await this.Cert.getAllUserCert(user1.address)
    expect(b.length).to.equal(3)
    expect(b[0]).to.equal('haha1')
    expect(b[1]).to.equal('haha2')
    expect(b[2]).to.equal('haha3')
  });
})
