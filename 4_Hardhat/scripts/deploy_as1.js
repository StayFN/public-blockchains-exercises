// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

    // Get signers added in hardhat.config.js
    const [signer1, signer2] = await hre.ethers.getSigners();

    // Pick the deployer (default is signer1).
    const signer = signer1;

    const Ass = await hre.ethers.getContractFactory("Assignment1", {
        signer: signer,
    });

    const ass = await Ass.deploy();

    console.log("Deploying assignment from address: " + signer.address);

    await ass.deployed();

    console.log(`Assignment deployed to ${ass.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
