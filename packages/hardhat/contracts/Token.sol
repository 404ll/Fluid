// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ------------------ Superfluid 核心接口 ------------------
import { ISuperfluid, ISuperfluidToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { IConstantFlowAgreementV1 } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

// ------------------ Superfluid CFA 库 ------------------
import { CFAv1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

contract MonadReadingPlatform {
    using CFAv1Library for CFAv1Library.InitData;

    ISuperfluid public host; // Superfluid host
    IConstantFlowAgreementV1 public cfa; // CFA
    ISuperfluidToken public token; // Monad 测试币（Super Token）

    CFAv1Library.InitData public cfaV1; // CFA 库

    mapping(address => bool) public isCreator;
    mapping(uint256 => address) public contentToCreator;

    event BecomeCreator(address indexed creator);
    event RegisterContent(uint256 indexed contentId, address indexed creator);
    event StartReading(address indexed reader, uint256 indexed contentId);
    event StopReading(address indexed reader, uint256 indexed contentId);

    constructor(ISuperfluid _host, IConstantFlowAgreementV1 _cfa, ISuperfluidToken _token) {
        host = _host;
        cfa = _cfa;
        token = _token;
        cfaV1 = CFAv1Library.InitData(host, cfa);
    }

    // ------------------ 创作者操作 ------------------
    function becomeCreator() external {
        isCreator[msg.sender] = true;
        emit BecomeCreator(msg.sender);
    }

    function registerContent(uint256 contentId) external {
        require(isCreator[msg.sender], "Not a creator");
        contentToCreator[contentId] = msg.sender;
        emit RegisterContent(contentId, msg.sender);
    }

    // ------------------ 阅读者操作 ------------------
    function startReading(uint256 contentId, int96 flowRate) external {
        address creator = contentToCreator[contentId];
        require(creator != address(0), "Content not registered");

        // 开启流支付：阅读者 -> 创作者
        cfaV1.createFlow(msg.sender, creator, token, flowRate);
        emit StartReading(msg.sender, contentId);
    }

    function stopReading(uint256 contentId) external {
        address creator = contentToCreator[contentId];
        require(creator != address(0), "Content not registered");

        // 停止流支付
        cfaV1.deleteFlow(msg.sender, creator, token);
        emit StopReading(msg.sender, contentId);
    }
}
