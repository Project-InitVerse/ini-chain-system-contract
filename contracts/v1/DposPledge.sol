// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Params.sol";


import "./library/ReentrancyGuard.sol";
import "./interfaces/IDposPledge.sol";
import "./interfaces/IDposFactory.sol";
import "./interfaces/IPunish.sol";

contract DposPledge is Params, ReentrancyGuard, IDposPledge {

    uint256 constant COEFFICIENT = 1e18;

    State public override state;

    address public override validator;

    uint256 public margin;

    //base on 10000
    uint256 public percent;

    PercentChange public pendingPercentChange;

    //reward for validator not for voters
    uint256 validatorReward;

    mapping(address => VoterInfo) public voters;

    //use to calc voter's reward
    uint256 public accRewardPerShare;

    uint256 public override totalVote;

    uint256 public punishBlk;

    uint256 public exitBlk;

    struct PercentChange {
        uint256 newPercent;
        uint256 submitBlk;
    }

    modifier onlyValidator() {
        require(msg.sender == validator, "Only validator allowed");
        _;
    }

    modifier onlyValidPercent(uint256 _percent) {
        //zero represents null value, trade as invalid
        require(_percent <= PERCENT_BASE*3/10, "Invalid percent");
        _;
    }

    event ChangeManager(address indexed manager);
    event SubmitPercentChange(uint256 indexed percent);
    event ConfirmPercentChange(uint256 indexed percent);
    event AddMargin(address indexed sender, uint256 amount);
    event ChangeState(State indexed state);
    event Exit(address indexed validator);
    event WithdrawMargin(address indexed sender, uint256 amount);
    event ExitVote(address indexed sender, uint256 amount);
    event WithdrawValidatorReward(address indexed sender, uint256 amount);
    event WithdrawVoteReward(address indexed sender, uint256 amount);
    event Deposit(address indexed sender, uint256 amount);
    event Withdraw(address indexed sender, uint256 amount);
    event Punish(address indexed validator, uint256 amount);
    event RemoveIncoming(address indexed validator, uint256 amount);

    constructor(
        address _validator,
        uint256 _percent,
        State _state
    )onlyValidAddress(_validator) onlyValidPercent(_percent) {
        validator = _validator;
        percent = _percent;
        state = _state;
        totalVote = 1000;
    }

    // only for chain hard fork to init poa validators
    function initialize() external onlyValidatorsContract onlyNotInitialized {
        initialized = true;
        validatorsContract.improveRanking();
    }

    //base on 1000
    function submitPercentChange(uint256 _percent) external onlyValidator onlyValidPercent(_percent) {
        pendingPercentChange.newPercent = _percent;
        pendingPercentChange.submitBlk = block.number;

        emit SubmitPercentChange(_percent);
    }

    function confirmPercentChange() external onlyValidator onlyValidPercent(pendingPercentChange.newPercent) {
        require(
            pendingPercentChange.submitBlk > 0 &&
                block.number-pendingPercentChange.submitBlk > PercentChangeLockPeriod,
            "Interval not long enough"
        );

        percent = pendingPercentChange.newPercent;
        pendingPercentChange.newPercent = 0;
        pendingPercentChange.submitBlk = 0;

        emit ConfirmPercentChange(percent);
    }

    function isIdleStateLike() internal view returns (bool) {
        return state == State.Idle || (state == State.Jail && block.number-punishBlk > JailPeriod);
    }

    function addMargin() external payable onlyValidator {
        require(isIdleStateLike(), "Incorrect state");
        require(exitBlk == 0 || block.number-exitBlk > MarginLockPeriod, "Interval not long enough");
        require(msg.value > 0, "Value should not be zero");

        exitBlk = 0;
        margin = margin+msg.value;
        emit AddMargin(msg.sender, msg.value);
        if (margin >= PosMinMargin) {
            state = State.Ready;
            punishContract.cleanPunishRecord(validator);
            validatorsContract.improveRanking();
            emit ChangeState(state);
        }
    }

    function switchState(bool pause) external override onlyValidatorsContract {
        if (pause) {
            require(isIdleStateLike() || state == State.Ready, "Incorrect state");

            state = State.Pause;
            emit ChangeState(state);
            validatorsContract.removeRanking();
            return;
        } else {
            require(state == State.Pause, "Incorrect state");

            state = State.Idle;
            emit ChangeState(state);
            return;
        }
    }

    function punish() external override onlyPunishContract {
        punishBlk = block.number;

        if (state != State.Pause) {
            state = State.Jail;
            emit ChangeState(state);
        }
        validatorsContract.removeRanking();

        uint256 _punishAmount = margin >= PunishAmount ? PunishAmount : margin;
        if (_punishAmount > 0) {
            margin = margin-(_punishAmount);
            sendValue(payable(address(0)), _punishAmount);
            emit Punish(validator, _punishAmount);
        }

        return;
    }

    function removeValidatorIncoming() external override onlyPunishContract {
        validatorsContract.withdrawReward();

        uint256 _incoming = validatorReward < PunishAmount ? validatorReward : PunishAmount;

        validatorReward = validatorReward-(_incoming);
        if (_incoming > 0) {
            sendValue(payable(address(0)), _incoming);
            emit RemoveIncoming(validator, _incoming);
        }
    }

    function exit() external onlyValidator {
        require(state == State.Ready || isIdleStateLike(), "Incorrect state");
        exitBlk = block.number;

        if (state != State.Idle) {
            state = State.Idle;
            emit ChangeState(state);

            validatorsContract.removeRanking();
        }
        emit Exit(validator);
    }

    function withdrawMargin() external nonReentrant onlyValidator {
        require(isIdleStateLike(), "Incorrect state");
        require(exitBlk > 0 && block.number-(exitBlk) > MarginLockPeriod, "Interval not long enough");
        require(margin > 0, "No more margin");

        exitBlk = 0;

        uint256 _amount = margin;
        margin = 0;
        sendValue(payable(msg.sender), _amount);
        emit WithdrawMargin(msg.sender, _amount);
    }

    function receiveReward() external payable onlyValidatorsContract {
        uint256 _rewardForValidator = msg.value*(percent)/(PERCENT_BASE);
        validatorReward = validatorReward+(_rewardForValidator);

        if (totalVote > 0) {
            accRewardPerShare = (msg.value-_rewardForValidator)*(COEFFICIENT)/(totalVote)+(
                accRewardPerShare
            );
        }
    }

    function withdrawValidatorReward() external payable nonReentrant onlyValidator {
        validatorsContract.withdrawReward();
        require(validatorReward > 0, "No more reward");

        uint256 _amount = validatorReward;
        validatorReward = 0;
        sendValue(payable(msg.sender), _amount);
        emit WithdrawValidatorReward(msg.sender, _amount);
    }

    function getValidatorPendingReward() external view returns (uint256) {
        uint256 _poolPendingReward = validatorsContract.pendingReward(IDposPledge(address(this)));
        uint256 _rewardForValidator = _poolPendingReward*(percent)/(PERCENT_BASE);

        return validatorReward+(_rewardForValidator);
    }

    function getPendingReward(address _voter) external view override returns (uint256) {
        uint256 _poolPendingReward = validatorsContract.pendingReward(IDposPledge(address(this)));
        uint256 _rewardForValidator = _poolPendingReward*(percent)/(PERCENT_BASE);

        uint256 _share = accRewardPerShare;
        if (totalVote > 0) {
            _share = (_poolPendingReward-_rewardForValidator)*(COEFFICIENT)/(totalVote)+(_share);
        }

        return _share*(voters[_voter].amount)/(COEFFICIENT)-(voters[_voter].rewardDebt);
    }

    function deposit() external payable nonReentrant {
        validatorsContract.withdrawReward();

        uint256 _pendingReward = accRewardPerShare*(voters[msg.sender].amount)/(COEFFICIENT)-(
            voters[msg.sender].rewardDebt
        );

        if (msg.value > 0) {
            voters[msg.sender].amount = voters[msg.sender].amount+(msg.value);
            voters[msg.sender].rewardDebt = voters[msg.sender].amount*(accRewardPerShare)/(COEFFICIENT);
            totalVote = totalVote+(msg.value);
            emit Deposit(msg.sender, msg.value);

            if (state == State.Ready) {
                validatorsContract.improveRanking();
            }
        } else {
            voters[msg.sender].rewardDebt = voters[msg.sender].amount*(accRewardPerShare)/(COEFFICIENT);
        }

        if (_pendingReward > 0) {
            sendValue(payable(msg.sender), _pendingReward);
            emit WithdrawVoteReward(msg.sender, _pendingReward);
        }
    }

    function exitVote(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Value should not be zero");
        require(_amount <= voters[msg.sender].amount, "Insufficient amount");

        validatorsContract.withdrawReward();

        uint256 _pendingReward = accRewardPerShare*(voters[msg.sender].amount)/(COEFFICIENT)-(
            voters[msg.sender].rewardDebt
        );

        totalVote = totalVote-(_amount);

        voters[msg.sender].amount = voters[msg.sender].amount-(_amount);
        voters[msg.sender].rewardDebt = voters[msg.sender].amount*(accRewardPerShare)/(COEFFICIENT);

        if (state == State.Ready) {
            validatorsContract.lowerRanking();
        }

        voters[msg.sender].withdrawPendingAmount = voters[msg.sender].withdrawPendingAmount+(_amount);
        voters[msg.sender].withdrawExitBlock = block.number;

        sendValue(payable(msg.sender), _pendingReward);

        emit ExitVote(msg.sender, _amount);
        emit WithdrawVoteReward(msg.sender, _pendingReward);
    }

    function withdraw() external nonReentrant {
        require(block.number-(voters[msg.sender].withdrawExitBlock) > WithdrawLockPeriod, "Interval too small");
        require(voters[msg.sender].withdrawPendingAmount > 0, "Value should not be zero");

        uint256 _amount = voters[msg.sender].withdrawPendingAmount;
        voters[msg.sender].withdrawPendingAmount = 0;
        voters[msg.sender].withdrawExitBlock = 0;

        sendValue(payable(msg.sender), _amount);
        emit Withdraw(msg.sender, _amount);
    }
    function getVoterInfo(address _user)external view override returns (VoterInfo memory){
        return voters[_user];
    }
    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    //TODO : for test
    /*
    function changeVote(uint _vote) external {
        totalVote = _vote;
    }

    function changeVoteAndRanking(IDposFactory _pool, uint _vote) external {
        totalVote = _vote;

        if (_vote > totalVote) {
            _pool.improveRanking();
        } else {
            _pool.lowerRanking();
        }
    }

    function changeState(State _state) external {
        state = _state;
    }*/
}
