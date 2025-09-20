// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUserManager {
    // 用户信息结构
    struct UserInfo {
        uint256 totalEarnings;    // 总收益
        bool isCreator;           // 是否是创作者（一次付费，永久有效）
        uint256 creatorFee;       // 成为创作者时支付的费用
        uint256 creatorTime;      // 成为创作者的时间
    }
    
    // 事件
    event UserBecameCreator(address indexed user, uint256 fee);
    event UserEarningsUpdated(address indexed user, uint256 newEarnings, uint256 totalEarnings);
    event CreatorFeeUpdated(uint256 newFee);
    
    // 主要功能
    function becomeCreator() external payable; // 一次付费3 Monad测试币，永久成为创作者
    function addEarnings(address user, uint256 amount) external;
    
    // 查询功能
    function getUserInfo(address user) external view returns (UserInfo memory);
    function isUserCreator(address user) external view returns (bool);
    function getUserEarnings(address user) external view returns (uint256);
    
    // 管理员功能
    function updateCreatorFee(uint256 newFee) external;
    function withdrawFees() external;
    
    // 查询参数
    function getCreatorFee() external view returns (uint256);
}