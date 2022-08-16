// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  const Vesting = await hre.ethers.getContractFactory("VestingWallet");
  const vesting = await Vesting.deploy();
  await vesting.deployed();

  const AddressProvider = await hre.ethers.getContractFactory(
    "AddressProvider"
  );
  const addressProvider = await AddressProvider.deploy();
  await addressProvider.deployed();

  const Factory = await hre.ethers.getContractFactory("ParcelVestingFactory");
  const factory = await Factory.deploy(addressProvider.address);
  await factory.deployed();

  const VestingOwnerNft = await hre.ethers.getContractFactory(
    "VestingOwnership"
  );
  const vestingOwnerNft = await VestingOwnerNft.deploy(factory.address);
  await vestingOwnerNft.deployed();

  await addressProvider.setVesting(vesting.address);
  await addressProvider.setVestingOwnershipNft(vestingOwnerNft.address);
  await addressProvider.setParcelFactory(factory.address);

  console.log(vesting.address);
  console.log(addressProvider.address);
  console.log(vestingOwnerNft.address);
  console.log(factory.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
