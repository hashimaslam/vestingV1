// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.1;
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Parcel's AddressResgistry
/// @dev Parcel's address registry of module implementations
contract AddressRegistry is Ownable {
  event NewModuleAddded(
    address indexed impl,
    bytes32 indexed name,
    address indexed addedby
  );
  event ModuleStatusUpdated(
    address indexed impl,
    bytes32 indexed name,
    bool indexed currStatus,
    address updatedby
  );

  //implemenation address of available modules
  mapping(bytes32 => address) public implementations;
  //Holding  status of the added implementation
  mapping(bytes32 => bool) public implementationStatus;
  //Name of the modules added
  bytes32[] public moduleNames;

  /// @dev Add incentive modules
  /// @param impl implementation address of the module
  /// @param name name of the module
  /// @return Returns true if the module added properly

  function addModule(address impl, bytes32 name)
    external
    onlyOwner
    returns (bool)
  {
    require(implementations[name] == address(0), "Already added");
    require(impl != address(0), "Not a valid module");
    implementations[name] = impl;
    implementationStatus[name] = true;

    emit NewModuleAddded(impl, name, address(msg.sender));
    return true;
  }

  /// @dev Toggle state of the added module (enable or disable as bool)
  /// @param status bool value of the status to be toggled
  /// @param name name of the module the toggle should apply
  function toggle(bool status, bytes32 name) external onlyOwner {
    require(implementations[name] != address(0), "No module found");
    require(implementationStatus[name] != status, "State already exists");
    implementationStatus[name] = status;
    emit ModuleStatusUpdated(
      implementations[name],
      name,
      status,
      address(msg.sender)
    );
  }

  /// @notice Get module address
  /// @param name name of the module
  /// @return returns the address of the module name passed as param
  function getModuleAddress(bytes32 name) external view returns (address) {
    require(implementations[name] != address(0), "No module found");
    require(implementationStatus[name] == true, "Module disabled");
    return implementations[name];
  }

}
