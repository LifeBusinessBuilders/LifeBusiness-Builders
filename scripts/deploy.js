const { ethers, upgrades } = require("hardhat");

async function main() {
    const LifeBusinessCoin = await ethers.getContractFactory("LifeBusinessCoin");

    // Deploy Logic Contract
    const logic = await LifeBusinessCoin.deploy();
    await logic.deployed();
    console.log("Logic contract deployed at:", logic.address);

    // Encode initializer with multiSigWallet
    const multiSigWallet = "0xYourMultiSigWalletAddress"; // Update with the correct wallet
    const data = logic.interface.encodeFunctionData("initialize", [multiSigWallet]);

    // Deploy ERC1967Proxy with logic and initializer
    const Proxy = await ethers.getContractFactory("ERC1967Proxy");
    const proxy = await Proxy.deploy(logic.address, data);
    await proxy.deployed();
    console.log("Proxy deployed at:", proxy.address);

    // Attach to Proxy
    const lifeBusinessCoin = LifeBusinessCoin.attach(proxy.address);
    console.log("Token name:", await lifeBusinessCoin.name());
    console.log("Token symbol:", await lifeBusinessCoin.symbol());
    console.log("Admin role:", await lifeBusinessCoin.hasRole(await lifeBusinessCoin.DEFAULT_ADMIN_ROLE(), multiSigWallet));
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
