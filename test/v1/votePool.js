const Validators = artifacts.require('cache/solpp-generated-contracts/v1/DposFactory.sol:DposFactory');
const Punish = artifacts.require('Punish');
const VotePool = artifacts.require('DposPledge');

const {web3, BN} = require('@openzeppelin/test-helpers/src/setup');
const truffleAssert = require('truffle-assertions')

const Pos = 0
const Poa = 1

contract("VotePool test", accounts => {
    let validators;
    let punish;

    before('deploy', async () => {
        validators = await Validators.new()
        await validators.initialize(accounts.slice(10, 15), accounts[0], {gas: 12450000})
        punish = await Punish.new()
        punish.setAddress(validators.address,punish.address)
        punish.initialize()
    })

    it("add pool", async () => {
        let tx = await validators.addValidator(accounts[0],20, {
            from: accounts[0],
            gas: 3000000
        })
        assert(tx.receipt.status)

        let pool = await VotePool.at(await validators.dposPledges(accounts[0]))
        await pool.setAddress(validators.address, punish.address)

        assert.equal(await pool.state(), 0)
    })

    // it('only pool', async() => {
    //     let inputs = [
    //         ['changeManager', [accounts[0]]],
    //     ]

    //     let pool = await VotePool.at(await validators.votePools(accounts[0]))

    //     for(let input of inputs) {
    //         try {
    //             await pool[input[0]](...input[1], {from: accounts[1]})
    //         }catch (e) {
    //             console.log(e)
    //             assert(e.message.search('Only pool') >= 0, input[0])
    //         }
    //     }
    // })

    /*
    it("change manager", async () => {
        let pool = await VotePool.at(await validators.votePools(accounts[0]))

        let tx = await pool.changeManager(accounts[1], {from: accounts[0]})
        truffleAssert.eventEmitted(tx, "ChangeManager", {manager: accounts[1]})
    })

     */

    it("add margin", async () => {
        let pool = await VotePool.at(await validators.dposPledges(accounts[0]))
        let tx = await pool.addMargin({
            from: accounts[0],
            value: web3.utils.toWei("1", "ether")
        })

        truffleAssert.eventEmitted(tx, 'AddMargin', ev => ev.sender === accounts[0]
            && ev.amount == web3.utils.toWei("1", "ether").toString())

        assert.equal(await pool.state(), 0)

        tx = await pool.addMargin({
            from: accounts[0],
            value: web3.utils.toWei("4", "ether")
        })
        truffleAssert.eventEmitted(tx, 'AddMargin', ev => ev.sender === accounts[0]
            && ev.amount == web3.utils.toWei("4", "ether").toString())

        truffleAssert.eventEmitted(tx, 'ChangeState', ev => ev.state == 1)

        assert.equal(await pool.state(), 1)
    })

    it("change percent", async () => {
        let pool = await VotePool.at(await validators.dposPledges(accounts[0]))
        let tx = await pool.submitPercentChange(80, {from: accounts[0]})
        truffleAssert.eventEmitted(tx, 'SubmitPercentChange', ev => ev.percent.toString() == 80)

        tx = await pool.confirmPercentChange({from: accounts[0]})
        truffleAssert.eventEmitted(tx, 'ConfirmPercentChange', ev => ev.percent.toString() == 80)
        assert.equal(await pool.percent(), 80)

        try {
            await pool.confirmPercentChange({from: accounts[0]})
        } catch (e) {
            assert(e, 'invalid confirm percent change')
            // assert(e.message.search('Invalid percent') >= 0, 'invalid confirm percent change')
        }
    })

    it("change percent", async () => {
        let pool = await VotePool.at(await validators.dposPledges(accounts[0]))
        try {
            await pool.submitPercentChange(0, {from: accounts[0]});
        } catch (e) {
            assert(e.message, 'from invalid account')
            // assert(e.message.search('Only manager allowed') >= 0, 'from invalid account')
        }

        try {
            await pool.submitPercentChange(0, {from: accounts[0]});
        } catch (e) {
            assert(e.message, 'change percent to 0')
            // assert(e.message.search('Invalid percent') >= 0, 'change percent to 0')
        }

        try {
            await pool.submitPercentChange(1001, {from: accounts[0]});
        } catch (e) {
            assert(e.message, 'change percent to 1001')
            // assert(e.message.search('Invalid percent') >= 0, 'change percent to 1001')
        }

        let tx = await pool.submitPercentChange(1, {from: accounts[0]});
        assert.equal(tx.receipt.status, true, 'change percent to 1')

        await pool.confirmPercentChange({from: accounts[0]});
        assert.equal(await pool.percent(), 1, "change percent success")
    })


    it("deposit", async () => {
        let pool = await VotePool.at(await validators.dposPledges(accounts[0]))

        params = [
            [1, 100],
            [2, 200],
            [3, 0.00001]
        ]

        let tops = [await pool.validator()]
        for (let p of params) {
            let tx = await pool.deposit({from: accounts[p[0]], value: web3.utils.toWei(p[1] + "", "ether")})
            truffleAssert.eventEmitted(tx, "Deposit", ev => ev.amount == web3.utils.toWei(p[1] + "", "ether").toString())
        }

        await validators.updateActiveValidatorSet(tops,200)
    })

    it("reward", async () => {
        await validators.distributeBlockReward({from: accounts[0], gas: 400000, value: web3.utils.toWei("1", "ether")})
        assert.equal(web3.utils.toWei("1", "ether"), await web3.eth.getBalance(validators.address))
        assert.equal(web3.utils.toWei("0.9", "ether"), await validators.pendingReward(await validators.dposPledges(accounts[0])))
    })

    it('switch state', async () => {
        let pool = await VotePool.at(await validators.dposPledges(accounts[0]))
        assert.equal(await pool.state(), 1, 'in ready state')
        await validators.switchState(accounts[0],true)
        assert.equal(await pool.state(), 2, 'in pause state')
        await validators.switchState(accounts[0],false,)
        assert.equal(await pool.state(), 0, 'in idle state')
    })

    it('punish', async () => {
        let pool = await VotePool.at(await validators.dposPledges(accounts[0]))
        pool.setAddress(validators.address,punish.address);
        let balanceBefore = await web3.eth.getBalance(pool.address);
        let marginBefore = await pool.margin();

        let punishAmount = await pool.PunishAmount()
        await punish.punisha(pool.address)

        assert.equal(balanceBefore - await web3.eth.getBalance(pool.address), punishAmount.toString(), 'contract balance check')
        assert.equal(marginBefore - await pool.margin(), punishAmount.toString(), 'contract margin check')
    })

    it("exit", async () => {
        let pool = await VotePool.at(await validators.dposPledges(accounts[0]))
        try {
            await pool.exit({from: accounts[1]})
        } catch (e) {
            assert(e, 'Incorrect state')
            // assert(e.message.search('Incorrect state') >= 0, 'Incorrect state')
        }

        await pool.addMargin({
            from: accounts[0],
            value: web3.utils.toWei("5", "ether")
        })

        assert.equal(await pool.state(), 1, 'Ready state')
        await pool.exit({from: accounts[0]})
        assert.equal(await pool.state(), 0, 'Idle state')
    })

    it("withdraw margin", async () => {
        let pool = await VotePool.at(await validators.dposPledges(accounts[0]))
        let margin = await pool.margin()

        let balanceBefore = await web3.eth.getBalance(accounts[0])
        let tx = await pool.withdrawMargin({from: accounts[0]})
        let fee = web3.utils.toBN((await web3.eth.getTransaction(tx.tx)).gasPrice).mul(web3.utils.toBN(tx.receipt.gasUsed))

        assert.equal(web3.utils.toBN(await web3.eth.getBalance(accounts[0])).sub(web3.utils.toBN(balanceBefore)).add(web3.utils.toBN(fee)).toString(), margin.toString())
    })
})

