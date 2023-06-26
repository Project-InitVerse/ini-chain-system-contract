# ~~For Dpos~~
~~For dpos test case, you should do follow change in the contracts~~

~~Remove comments :
1.DposFactory.sol:
line 74
line 293-298
2.DposPledge.sol:
line 343-360
3.Params.sol:
line 15-24
line 29-38
4.Punish.sol:
line 123-126~~

~~Add comment:
1.DposFactory.sol:
line 90-91
line 198
2.Params.sol:
line 11-12
line 39-46~~


# Validator 2.0

We use v2/ValidatorFactory.sol as the genesis contract for the chain validator
## Test
for test you should do follow change in the contracts;
- Remove comments

  v2/ValidatorFactory.sol:
  1. line 23
  2. line 55
  3. line 232
  4. line 306-308

  v2/PunishContract.sol:
  1. line 13
  2. lin2 35-27
- Add comments

  v2/ValidatorFactory.sol:
  1. line 21
  2. line 230
  3. line 454
  4. line 632
  5. line 636

     v2/PunishContract.sol:
  1. line 11
```
yarn hardhat test ./test/v2/validator.ts
```
## Init
```
yarn install
```
## Compile
```
yarn hardhat compile
```
