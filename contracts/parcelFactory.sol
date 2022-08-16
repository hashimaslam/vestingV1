// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.1;
import "./libraries/oz/clone.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
Parcel Factory - factory contract for dao's to interact and create instances for available modules
 */
interface IAddressRegistry {
  function getModuleAddress(bytes32 name) external view returns (address);
}

interface IOwnerShipNft {
  function mintNft(address to) external returns (uint256);
}

contract ParcelFactory {
  //Core events
  event NewModuleDeployed(
    address indexed deployedBy,
    bytes32 indexed module,
    address indexed proxy
  );

  address public registry;

  constructor(address _registry) {
    registry = _registry;
  }

  /// @notice build new proxy clone for available modules in parcel registry
  /// @dev data param should be encoded value of module's init function
  /// @param module module name in bytes32 format
  /// @param data encoded calldata to be executed(init function)
  /// @return returns the new proxy clone address of the module implementaion
  function build(bytes32 module, bytes calldata data)
    external
    returns (address)
  {
    //fetch the module address from the registry based upon the module name
    address target = IAddressRegistry(registry).getModuleAddress(module);
    require(target != address(0), "Factory: Invalid module");
    //create clone of the retrived module with call data
    address deployed = CloneFactory.clone(target);
    Address.functionCall(target, data);
    emit NewModuleDeployed(msg.sender, module, deployed);
    return deployed;
  }

  /// @notice build new proxy clone for available modules in parcel registry with calldata to be executed
  /// @dev data param should be encoded value array of module's init function and other functions to be called along with the creation time(eg: init function with [execute some operation])
  /// @param module module name in bytes32 format
  /// @param data array of encoded calldata to be executed
  /// @return returns the new proxy clone address of the module implementaion
  function buildAndexecute(bytes32 module, bytes[] calldata data)
    external
    returns (address)
  {
    //fetch the module address from the registry based upon the module name
    address target = IAddressRegistry(registry).getModuleAddress(module);
    require(target != address(0), "Factory: Invalid module");
    //create clone of the retrived module with call data
    address deployed = CloneFactory.clone(target);
    uint256 len = data.length;
    for (uint64 i = 0; i < len; i++) {
      Address.functionCall(target, data[i]);
    }
    emit NewModuleDeployed(msg.sender, module, deployed);
    return deployed;
  }
}
