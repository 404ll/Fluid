const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ReadingPlatform", function () {
  let Token, token, Platform, platform;
  let owner, user;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();

    // 部署 ERC20 Token
    Token = await ethers.getContractFactory("ERC20PresetMinterPauser");
    token = await Token.deploy("TestToken", "TT");
    await token.deployed();

    // 给用户一些代币
    await token.mint(user.address, ethers.utils.parseEther("100"));

    // 部署 ReadingPlatform
    Platform = await ethers.getContractFactory("ReadingPlatform");
    platform = await Platform.deploy(token.address);
    await platform.deployed();
  });

  it("should deposit tokens", async function () {
    const depositAmount = ethers.utils.parseEther("10");

    await token.connect(user).approve(platform.address, depositAmount);
    await platform.connect(user).deposit(depositAmount);

    const balance = await platform.balanceOf(user.address);
    expect(balance).to.equal(depositAmount);
  });

  it("should start and end reading and charge correctly", async function () {
    const depositAmount = ethers.utils.parseEther("10");

    await token.connect(user).approve(platform.address, depositAmount);
    await platform.connect(user).deposit(depositAmount);

    // 开始阅读
    await platform.connect(user).startReading(1);
    let status = await platform.readingStatus(user.address, 1);
    expect(status[0]).to.be.true; // isReading = true

    // 增加一点时间
    await ethers.provider.send("evm_increaseTime", [10]); // 10秒
    await ethers.provider.send("evm_mine");

    // 结束阅读
    await platform.connect(user).endReading(1);
    status = await platform.readingStatus(user.address, 1);
    expect(status[0]).to.be.false; // isReading = false

    const remainingBalance = await platform.balanceOf(user.address);
    expect(remainingBalance).to.equal(0); // 全部退回
  });
});
