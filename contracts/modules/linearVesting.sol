// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * Parcel Standard Vesting Contract
 */
interface IOwnerShipNft {
  function mintNft(address to) external returns (uint256);

  function ownerOf(uint256 tokenId) external view returns (address);
}

interface IAddressRegistry {
  function getModuleAddress(bytes32 name) external view returns (address);
}

contract Vesting is Ownable, Initializable {
  struct Schedule {
    uint256 totalAmount;
    uint256 claimedAmount;
    uint256 startTime;
    uint256 cliffTime;
    uint256 endTime;
    bool isFixed;
    address asset;
  }
  //static address
  address public registry;
  address public nft;
  // tokenId => scheduleId => schedule
  mapping(uint256 => mapping(uint256 => Schedule)) public schedules;
  //tokenId=>totalScheduleNumber
  mapping(uint256 => uint256) public numberOfSchedules;
  //asset=>amount
  mapping(address => uint256) public locked;

  event Claim(
    address indexed claimer,
    address indexed dao,
    uint256 amount,
    address asset
  );
  event NewVestingCreated(
    address indexed contributor,
    address indexed dao,
    uint256 indexed tokenId,
    uint256 amount,
    address asset,
    uint256 scheduleNumber
  );
  event Cancelled(
    address indexed cancelledBy,
    uint256 indexed tokenId,
    address indexed asset
  );

  function init(
    address _registry,
    address _nft,
    address dao
  ) public initializer {
    registry = _registry;
    nft = _nft;
    transferOwnership(dao);
  }

  /**
   * @notice Sets up a vesting schedule for a set user.
   * @dev adds a new Schedule to the schedules mapping.
   * @param account the account that a vesting schedule is being set up for. Will be able to claim tokens after
   *                the cliff period.
   * @param amount the amount of tokens being vested for the user.
   * @param asset the asset that the user is being vested
   * @param isFixed a flag for if the vesting schedule is fixed or not. Fixed vesting schedules can't be cancelled.
   * @param cliffWeeks the number of weeks that the cliff will be present at.
   * @param vestingWeeks the number of weeks the tokens will vest over (linearly)
   * @param startTime the timestamp for when this vesting should have started
   */
  function vest(
    address account,
    uint256 amount,
    address asset,
    bool isFixed,
    uint256 cliffWeeks,
    uint256 vestingWeeks,
    uint256 startTime
  ) public onlyOwner {
    // ensure cliff is shorter than vesting
    require(
      vestingWeeks > 0 && vestingWeeks >= cliffWeeks && amount > 0,
      "Vesting: invalid vesting params"
    );

    uint256 currentLocked = locked[asset];

    // require the token is present
    require(
      IERC20(asset).balanceOf(address(this)) >= currentLocked + amount,
      "Vesting: Not enough tokens"
    );

    //mint ownership NFT
    uint256 tokenId = IOwnerShipNft(nft).mintNft(account);

    // create the schedule
    uint256 currentNumSchedules = numberOfSchedules[tokenId];
    schedules[tokenId][currentNumSchedules] = Schedule(
      amount,
      0,
      startTime,
      startTime + (cliffWeeks * 1 weeks),
      startTime + (vestingWeeks * 1 weeks),
      isFixed,
      asset
    );
    numberOfSchedules[tokenId] = currentNumSchedules + 1;
    locked[asset] = currentLocked + amount;
    emit NewVestingCreated(account, msg.sender, tokenId, amount, asset,currentNumSchedules);
  }

  /**
   * @notice Sets up vesting schedules for multiple users within 1 transaction.
   * @dev adds a new Schedule to the schedules mapping.
   * @param accounts an array of the accounts that the vesting schedules are being set up for.
   *                 Will be able to claim tokens after the cliff period.
   * @param amount an array of the amount of tokens being vested for each user.
   * @param assets the asset that the user is being vested
   * @param isFixed bool setting if these vesting schedules can be rugged or not.
   * @param cliffWeeks the number of weeks that the cliff will be present at.
   * @param vestingWeeks the number of weeks the tokens will vest over (linearly)
   * @param startTime the timestamp for when this vesting should have started
   */
  function multiVest(
    address[] calldata accounts,
    uint256[] calldata amount,
    address[] calldata assets,
    bool[] calldata isFixed,
    uint256[] calldata cliffWeeks,
    uint256[] calldata vestingWeeks,
    uint256[] calldata startTime
  ) external onlyOwner {
    uint256 numberOfAccounts = accounts.length;
    require(
      amount.length == numberOfAccounts &&
        isFixed.length == numberOfAccounts &&
        cliffWeeks.length == numberOfAccounts &&
        vestingWeeks.length == numberOfAccounts &&
        startTime.length == numberOfAccounts,
      "Vesting: Array lengths differ"
    );
    
    for (uint256 i = 0; i < numberOfAccounts; i++) {
      vest(
        accounts[i],
        amount[i],
        assets[i],
        isFixed[i],
        cliffWeeks[i],
        vestingWeeks[i],
        startTime[i]
      );
    }
  }

  /**
   * @notice get the users ownershipt address
   * @param tokenId nft tokenId
   */
  function beneificary(uint256 tokenId) public view returns (address) {
    address contributor = IOwnerShipNft(nft).ownerOf(tokenId);
    return contributor;
  }

  /**
   * @notice allows users to claim vested tokens if the cliff time has passed.
   * @param scheduleNumber which schedule the user is claiming against
   * @param tokenId users identitiy as nft tokenId
   */
  function claim(uint256 tokenId, uint256 scheduleNumber) external {
    Schedule storage schedule = schedules[tokenId][scheduleNumber];
    require(
      schedule.cliffTime <= block.timestamp,
      "Vesting: cliff not reached"
    );
    require(schedule.totalAmount > 0, "Vesting: not claimable");

    // Get the amount to be distributed
    uint256 amount = calcDistribution(
      schedule.totalAmount,
      block.timestamp,
      schedule.startTime,
      schedule.endTime
    );

    // Cap the amount at the total amount
    amount = amount > schedule.totalAmount ? schedule.totalAmount : amount;
    uint256 amountToTransfer = amount - schedule.claimedAmount;
    schedule.claimedAmount = amount; // set new claimed amount based off the curve
    locked[schedule.asset] = locked[schedule.asset] - amountToTransfer;
    address claimer = beneificary(tokenId);
    require(
      IERC20(schedule.asset).transfer(claimer, amountToTransfer),
      "Vesting: transfer failed"
    );
    emit Claim(claimer, owner(), amountToTransfer, schedule.asset);
  }

  /**
   * @notice Allows a vesting schedule to be cancelled.
   * @dev Any outstanding tokens are returned to the system.
   * @param tokenId the account of the user whos vesting schedule is being cancelled.
   */
  function rug(uint256 tokenId, uint256 scheduleId) external onlyOwner {
    Schedule storage schedule = schedules[tokenId][scheduleId];
    require(!schedule.isFixed, "Vesting: Account is fixed");
    uint256 outstandingAmount = schedule.totalAmount - schedule.claimedAmount;
    require(outstandingAmount != 0, "Vesting: no outstanding tokens");
    schedule.totalAmount = 0;
    locked[schedule.asset] = locked[schedule.asset] - outstandingAmount;
    require(
      IERC20(schedule.asset).transfer(owner(), outstandingAmount),
      "Vesting: transfer failed"
    );
    emit Cancelled(msg.sender, tokenId, schedule.asset);
  }

  /**
   * @return calculates the amount of tokens to distribute to an account at any instance in time, based off some
   *         total claimable amount.
   * @param amount the total outstanding amount to be claimed for this vesting schedule.
   * @param currentTime the current timestamp.
   * @param startTime the timestamp this vesting schedule started.
   * @param endTime the timestamp this vesting schedule ends.
   */
  function calcDistribution(
    uint256 amount,
    uint256 currentTime,
    uint256 startTime,
    uint256 endTime
  ) public pure returns (uint256) {
    // avoid uint underflow
    if (currentTime < startTime) {
      return 0;
    }

    // if endTime < startTime, this will throw. Since endTime should never be
    // less than startTime in safe operation, this is fine.
    return (amount * (currentTime - startTime)) / (endTime - startTime);
  }

  /**
   * @notice Withdraws TCR tokens from the contract.
   * @dev blocks withdrawing locked tokens.
   */
  function withdraw(uint256 amount, address asset) external onlyOwner {
    IERC20 token = IERC20(asset);
    require(
      token.balanceOf(address(this)) - locked[asset] >= amount,
      "Vesting: Can't withdraw"
    );
    require(token.transfer(owner(), amount), "Vesting: withdraw failed");
  }
}
