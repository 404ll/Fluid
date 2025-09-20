// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ISuperfluidToken.sol";
import "./IUserManager.sol";

interface IUserRegistry {
    function isUserCreator(address user) external view returns (bool);
}

contract MonadReadingPlatform {

    ISuperfluidToken public token;
    IUserRegistry public registry;
    IUserManager public userManager;

    struct Flow {
        address sender;
        address receiver;
        int96 flowRate; // 每秒流量
        uint256 startTime;
    }

    struct Session {
        bool isReading;
        uint256 startTime;
        uint256 accruedAmount;
        address creator;
    }

    mapping(address => mapping(address => Flow)) public flows; // sender => receiver => Flow
    mapping(address => mapping(uint256 => Session)) public sessions; // reader => contentId => Session

    // ------------------ Events ------------------
    event FlowCreated(address indexed sender, address indexed receiver, int96 flowRate);
    event FlowUpdated(address indexed sender, address indexed receiver, int96 newFlowRate);
    event FlowDeleted(address indexed sender, address indexed receiver, uint256 totalAmountTransferred);
    event ReadingStarted(address indexed reader, uint256 contentId, address indexed creator);
    event ReadingEnded(address indexed reader, uint256 contentId, uint256 amountTransferred);
    event CreatorDeposit(address indexed creator, uint256 amount);
    event CreatorWithdraw(address indexed creator, uint256 amount);

    // ------------------ Constructor ------------------
    constructor(
        ISuperfluidToken _token,
        IUserRegistry _registry,
        IUserManager _userManager
    ) {
        token = _token;
        registry = _registry;
        userManager = _userManager;
    }

    // ------------------ 创作者充值 / 提现 ------------------
    function deposit(uint256 amount) external {
        require(userManager.isUserCreator(msg.sender), "Not a creator");
        require(amount > 0, "Amount must be > 0");

        token.transferFrom(msg.sender, address(this), amount);
        userManager.addEarnings(msg.sender, amount);

        emit CreatorDeposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(userManager.isUserCreator(msg.sender), "Not a creator");
        uint256 balance = userManager.getUserEarnings(msg.sender);
        require(balance >= amount, "Insufficient balance");

        // 需要 UserManager 支持扣减余额，如果没有，可以在这里加一个 subtract 函数
        userManager.addEarnings(msg.sender, amount * (-1)); // 如果 UserManager 支持负数操作
        token.transfer(msg.sender, amount);

        emit CreatorWithdraw(msg.sender, amount);
    }

    // ------------------ 阅读者流支付功能 ------------------
    function startReading(uint256 contentId, address creator, int96 flowRate) external {
        require(registry.isUserCreator(creator), "Not a creator");

        Session storage s = sessions[msg.sender][contentId];
        require(!s.isReading, "Already reading");

        s.isReading = true;
        s.startTime = block.timestamp;
        s.creator = creator;

        // 创建流支付
        _createFlow(msg.sender, creator, flowRate);

        emit ReadingStarted(msg.sender, contentId, creator);
    }

    function endReading(uint256 contentId) external {
        Session storage s = sessions[msg.sender][contentId];
        require(s.isReading, "Not reading");

        Flow storage f = flows[msg.sender][s.creator];

        // 结算流支付
        uint256 elapsed = block.timestamp - f.startTime;
        uint256 owed = uint256(int256(elapsed) * f.flowRate);

        s.accruedAmount += owed;
        s.isReading = false;

        // 删除流
        _deleteFlow(msg.sender, s.creator);

        emit ReadingEnded(msg.sender, contentId, owed);

        // 将收益增加到创作者账户
        userManager.addEarnings(s.creator, owed);
    }

    // ------------------ 简化 CFA 核心函数 ------------------
    function _createFlow(address sender, address receiver, int96 flowRate) internal {
        Flow storage f = flows[sender][receiver];
        require(f.flowRate == 0, "Flow already exists");

        f.sender = sender;
        f.receiver = receiver;
        f.flowRate = flowRate;
        f.startTime = block.timestamp;

        emit FlowCreated(sender, receiver, flowRate);
    }

    function _updateFlow(address sender, address receiver, int96 newFlowRate) internal {
        Flow storage f = flows[sender][receiver];
        require(f.flowRate > 0, "Flow does not exist");

        uint256 elapsed = block.timestamp - f.startTime;
        uint256 owed = uint256(int256(elapsed) * f.flowRate);

        f.flowRate = newFlowRate;
        f.startTime = block.timestamp;

        emit FlowUpdated(sender, receiver, newFlowRate);
    }

    function _deleteFlow(address sender, address receiver) internal {
        Flow storage f = flows[sender][receiver];
        require(f.flowRate > 0, "Flow does not exist");

        emit FlowDeleted(sender, receiver, uint256(int256(block.timestamp - f.startTime) * f.flowRate));

        delete flows[sender][receiver];
    }

    // ------------------ 查询 ------------------
    function getFlow(address sender, address receiver) external view returns(int96 flowRate, uint256 startTime) {
        Flow storage f = flows[sender][receiver];
        return (f.flowRate, f.startTime);
    }

    function getReadingSession(address reader, uint256 contentId) external view returns(bool isReading, uint256 startTime, uint256 accruedAmount, address creator) {
        Session storage s = sessions[reader][contentId];
        return (s.isReading, s.startTime, s.accruedAmount, s.creator);
    }
}
