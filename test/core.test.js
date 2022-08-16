const { expect } = require("chai");
const { ethers } = require("hardhat");
const { waffle } = require("hardhat");
const provider = waffle.provider;

describe("ParcelVestingFactory", function () {
  const wallets = provider.getWallets();
  const [dao1, dao2, con1, con2] = wallets;
  //   const signer = ethers.provider.getSigner(dao1);
  const erc20 = "0xc3dbf84abb494ce5199d5d4d815b10ec29529ff8";

  let Factory;
  let factory;
  let Vesting;
  let vesting;
  let AddressProvider;
  let addressProvider;
  let VestingOwnerNft;
  let vestingOwnerNft;

  beforeEach(async () => {
    //  Deployment steps
    Vesting = await ethers.getContractFactory("VestingWallet");
    vesting = await Vesting.deploy();
    await vesting.deployed();

    AddressProvider = await ethers.getContractFactory("AddressProvider");
    addressProvider = await AddressProvider.deploy();
    await addressProvider.deployed();

    Factory = await ethers.getContractFactory("ParcelVestingFactory");
    factory = await Factory.deploy(addressProvider.address);
    await factory.deployed();

    VestingOwnerNft = await ethers.getContractFactory("VestingOwnership");
    vestingOwnerNft = await VestingOwnerNft.deploy(factory.address);
    await vestingOwnerNft.deployed();

    await addressProvider.setVesting(vesting.address);
    await addressProvider.setVestingOwnershipNft(vestingOwnerNft.address);
    await addressProvider.setParcelFactory(factory.address);
  });
  it("Should deploy and create proxy with vesting schedule", async function () {
    const impAddress = await addressProvider.getVesting();
    expect(impAddress).to.equals(vesting.address);

    const vestingProxyresult1 = await factory.deployVestingProxy(dao1.address);
    const result1 = await vestingProxyresult1.wait();
    const vestingProxyresult2 = await factory.deployVestingProxy(dao2.address);
    const result2 = await vestingProxyresult2.wait();
    //console.log(result1, "from result 1");
    // console.log(result2.events[2].args.vestingWalletProxy, "from result 2");
    const proxyAdd1 = result1.events[2].args.vestingWalletProxy;

    console.log(result1.events[2].args);
    const proxyAdd2 = result2.events[2].args.vestingWalletProxy;
    //Vesting contract proxy intialization
    const vestingWallet1 = await ethers.getContractAt(
      "VestingWallet",
      proxyAdd1
    );
    const vestingWallet2 = await ethers.getContractAt(
      "VestingWallet",
      proxyAdd2
    );
    const vestingproxySelf1 = await ethers.getContractAt(
      "VestingProxy",
      proxyAdd1,
      dao1
    );
    const vestingproxySelf2 = await ethers.getContractAt(
      "VestingProxy",
      proxyAdd2,
      dao2
    );

    //  Calling Vesting Proxies to check the states

    const admin1 = await vestingproxySelf1.getAdmin();
    const admin2 = await vestingproxySelf2.getAdmin();
    console.log(admin1, admin2, "from admins");
    expect(admin1).to.equals(
      dao1.address,
      "Dao1 address matching with proxy admin"
    );
    expect(admin2).to.equals(
      dao2.address,
      "Dao2 address matching with proxy admin"
    );

    //  Creating Vesting Schedule for contributor
    const tx1 = await vestingproxySelf1.createVesting(con1.address, erc20, {
      _released: 0,
      _revoked: false,
      _beneficiary: con1.address,
      _start: 1650901586,
      _duration: 2000,
      _revocable: true,
      _cliff: 1650900986,
      vestingType: 1,
    });
    const vesting2 = await vestingproxySelf1.createVesting(
      con2.address,
      erc20,
      {
        _released: 0,
        _revoked: false,
        _beneficiary: con1.address,
        _start: 1650901588,
        _duration: 7100,
        _revocable: true,
        _cliff: 1650900966,
        vestingType: 1,
      }
    );
    const tx2 = await vestingproxySelf2.createVesting(con1.address, erc20, {
      _released: 0,
      _revoked: false,
      _beneficiary: con1.address,
      _start: 1650907586,
      _duration: 3000,
      _revocable: true,
      _cliff: 1650900996,
      vestingType: 1,
    });
    /**
       [0,false,"0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db",1650905586,4000,true,1650900986,1]
       * 
       */
    const txMinted1 = await tx1.wait();
    console.log(txMinted1.events[2].args);
    const vesting2tx = await vesting2.wait();
    console.log(vesting2tx.events[2].args);
    const txMinted2 = await tx2.wait();
    console.log(txMinted2.events[2].args);

    // const startMint = await vestingproxySelf1.getstart(con1.address, erc20);
    // const startMint2 = await vestingproxySelf2.getstart(con1.address, erc20);
    // console.log(startMint, startMint2, "from Starts of proxies");

    const start1 = await vestingWallet1
      .attach(proxyAdd1)
      .start(txMinted1.events[2].args.tokenId.toString(), erc20);
    const vesting2Start = await vestingWallet1
      .attach(proxyAdd1)
      .start(vesting2tx.events[2].args.tokenId.toString(), erc20);
    const start2 = await vestingWallet2
      .attach(proxyAdd2)
      .start(txMinted2.events[2].args.tokenId.toString(), erc20);

    console.log(start1, start2, vesting2Start);
  });
});
