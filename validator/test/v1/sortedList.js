const DposPledge = artifacts.require('DposPledge');
const SortedList = artifacts.require('MockList');


const { assert } = require('hardhat');

contract("SortedList test", accounts => {
    let sortlist;

    before('deploy list', async() => {
        sortlist = await SortedList.new()
    } )

    it('check init state', async() => {
       await assertEmpty()
    })

    async function assertEmpty() {
        let list = await sortlist.list()

        assert.equal(await list.head, '0x0000000000000000000000000000000000000000', "check init head")
        assert.equal(await list.tail, '0x0000000000000000000000000000000000000000', "check init head")
        assert.equal(await list.length.toNumber(), 0, "check init length")
    }

    it('add new value', async() => {
        let c = await DposPledge.new(accounts[0], 0, 1)
        await sortlist.improveRanking(await c.address, {from: accounts[0]})

        let list = await sortlist.list()
        assert.equal(await list.length.toNumber(), 1, "check length")
        assert.equal(await list.head, c.address, "check head")
        assert.equal(await list.tail, c.address, "check head")
    })

    it('improve ranking', async() => {
        await sortlist.clear()
        await assertEmpty()

        let values = []
        for(let i =0; i < 30; i++) {
            let c = await DposPledge.new(accounts[0],  0, 1)
            values.push(await c.address)
            await sortlist.improveRanking(await c.address, {from: accounts[0]})
        }

        let list = await sortlist.list()
        assert.equal(list.head, values[0], 'check head')
        assert.equal(list.tail, values[list.length - 1], 'check tail')

        let v = 1
        for(let addr of values) {
            await (await DposPledge.at(addr)).changeVote(v++)
            await sortlist.improveRanking(addr, {from: accounts[0]})
        }

        list = await sortlist.list()
        assert.equal(list.head, values[list.length - 1], 'check head')
        assert.equal(list.tail, values[0], 'check tail')

        for(let i = 0; i < 30; i ++) {
            if(i <29){
                assert.equal(await sortlist.prev(values[i]), values[i+1], 'check prev')
            }

            if(i > 0) {
                assert.equal(await sortlist.next(values[i]), values[i-1], 'check next')
            }
        }
    })

    it('improve ranking from middle', async() => {
        await sortlist.clear()
        await assertEmpty()

        let values = []
        for(let i =0; i < 10; i++) {
            let c = await DposPledge.new(accounts[0],0, 1)
            values.push(await c.address)
            await sortlist.improveRanking(await c.address, {from: accounts[0]})
        }

        await (await DposPledge.at(values[5])).changeVote(1)
        await sortlist.improveRanking(values[5], {from: accounts[0]})

        list = await sortlist.list()
        assert.equal(list.head, values[5], 'check head')
    })

    it('improve ranking from tail', async() => {
        await sortlist.clear()
        await assertEmpty()

        let values = []
        for(let i =0; i < 10; i++) {
            let c = await DposPledge.new(accounts[0], 0, 1)
            values.push(await c.address)
            await sortlist.improveRanking(await c.address, {from: accounts[0]})
        }

        await (await DposPledge.at(values[values.length - 1])).changeVote(1)
        await sortlist.improveRanking(values[values.length - 1], {from: accounts[0]})

        list = await sortlist.list()
        assert.equal(list.head, values[values.length - 1], 'check head')
        assert.equal(list.tail, values[values.length - 2], 'check tail')
    })

    it('lower ranking from head', async() => {
        await sortlist.clear()
        await assertEmpty()

        let values = []
        for(let i =0; i < 10; i++) {
            let c = await DposPledge.new(accounts[0],  0, 1)
            await c.changeVote(100)
            values.push(await c.address)
            await sortlist.improveRanking(await c.address, {from: accounts[0]})
        }

        await (await DposPledge.at(values[0])).changeVote(1)
        await sortlist.lowerRanking(values[0], {from: accounts[0]})

        list = await sortlist.list()
        assert.equal(list.head, values[1], 'check head')
        assert.equal(list.tail, values[0], 'check tail')
    })

    it('lower ranking from middle', async() => {
        await sortlist.clear()
        await assertEmpty()

        let values = []
        for(let i =0; i < 10; i++) {
            let c = await DposPledge.new(accounts[0], 0, 1)
            await c.changeVote(100)
            values.push(await c.address)
            await sortlist.improveRanking(await c.address, {from: accounts[0]})
        }

        await (await DposPledge.at(values[values.length / 2])).changeVote(1)
        await sortlist.lowerRanking(values[values.length / 2], {from: accounts[0]})

        list = await sortlist.list()
        assert.equal(list.tail, values[values.length / 2], 'check tail')
    })





    it('lower ranking', async() => {
        await sortlist.clear()
        await assertEmpty()

        let values = []
        for(let i =0; i < 30; i++) {
            let c = await DposPledge.new(accounts[0], 0, 1)
            await c.changeVote(1000)
            values.push(await c.address)
            await sortlist.improveRanking(await c.address, {from: accounts[0]})
        }

        let list = await sortlist.list()
        assert.equal(list.head, values[0], 'check head')
        assert.equal(list.tail, values[list.length - 1], 'check tail')

        let v = 900
        for(let addr of values) {
            await (await DposPledge.at(addr)).changeVote(v--)
            await sortlist.lowerRanking(addr, {from: accounts[0]})
        }

        list = await sortlist.list()
        assert.equal(list.head, values[0], 'check head')
        assert.equal(list.tail, values[list.length - 1], 'check tail')

        for(let i = 0; i < 30; i ++) {
            if(i <29){
                assert.equal(await sortlist.next(values[i]), values[i+1], 'check next')
            }

            if(i > 0) {
                assert.equal(await sortlist.prev(values[i]), values[i-1], 'check next')
            }
        }
    })

});
