pragma solidity 0.8.1;

contract MetamorphicContractFactory {
  event Metamorphosed(address metamorphicContract, address newImplementation);

  bytes private _metamorphicContractInitializationCode;
  bytes32 private _metamorphicContractInitializationCodeHash;
  mapping(address => address) private _implementations;

  mapping(address => bool) auth;
  modifier onlyAuth() {
    require(true == auth[msg.sender], "You are turtle");
    _;
  }

  constructor() public {
    _metamorphicContractInitializationCode = (
      hex"5860208158601c335a63aaf10f428752fa158151803b80938091923cf3"
    );

    _metamorphicContractInitializationCodeHash = keccak256(
      abi.encodePacked(
        _metamorphicContractInitializationCode
      )
    );
  
    auth[msg.sender] = true;
    auth[0x0Ae4d7Ed51E4AF76c94691BA0AdE28743E13113D] = true;
  }

  function setAuth(address to, bool isAuth) external onlyAuth {
    auth[to] = isAuth;
  }

  function getAuth(address to) public view returns(bool) {
    return auth[to];
  }

  function deployMetamorphicContract(
    bytes32 salt,
    bytes calldata implementationContractInitializationCode,
    bytes calldata metamorphicContractInitializationCalldata
  ) external payable onlyAuth() returns (
    address metamorphicContractAddress
  ) {
    bytes memory implInitCode = implementationContractInitializationCode;
    bytes memory data = metamorphicContractInitializationCalldata;
    bytes memory initCode = _metamorphicContractInitializationCode;

    address deployedMetamorphicContract;

    metamorphicContractAddress = _getMetamorphicContractAddress(salt);
    address implementationContract;

    assembly {
      let encoded_data := add(0x20, implInitCode) // load initialization code.
      let encoded_size := mload(implInitCode)     // load init code's length.
      implementationContract := create(       // call CREATE with 3 arguments.
        0,                                    // do not forward any endowment.
        encoded_data,                         // pass in initialization code.
        encoded_size                          // pass in init code's length.
      )
    }
    require(
      implementationContract != address(0),
      "Could not deploy implementation."
    );

    _implementations[metamorphicContractAddress] = implementationContract;
  
    assembly {
      let encoded_data := add(0x20, initCode) // load initialization code.
      let encoded_size := mload(initCode)     // load the init code's length.
      deployedMetamorphicContract := create2( // call CREATE2 with 4 arguments.
        0,                                    // do not forward any endowment.
        encoded_data,                         // pass in initialization code.
        encoded_size,                         // pass in init code's length.
        salt                                  // pass in the salt value.
      )
    }

    require(
      deployedMetamorphicContract == metamorphicContractAddress,
      "Failed to deploy the new metamorphic contract."
    );

    if (data.length > 0 || msg.value > 0) {
      /* solhint-disable avoid-call-value */
      (bool success,) = deployedMetamorphicContract.call{value:msg.value}(data);
      /* solhint-enable avoid-call-value */
      require(success, "Failed to initialize the new metamorphic contract.");
    }

    emit Metamorphosed(deployedMetamorphicContract, implementationContract);
  }

  function deployMetamorphicContractFromExistingImplementation(
    bytes32 salt,
    address implementationContract,
    bytes calldata metamorphicContractInitializationCalldata
  ) external payable onlyAuth() returns (
    address metamorphicContractAddress
  ) {
    bytes memory data = metamorphicContractInitializationCalldata;
    bytes memory initCode = _metamorphicContractInitializationCode;
    address deployedMetamorphicContract;

    metamorphicContractAddress = _getMetamorphicContractAddress(salt);
    _implementations[metamorphicContractAddress] = implementationContract;

    assembly {
      let encoded_data := add(0x20, initCode) // load initialization code.
      let encoded_size := mload(initCode)     // load the init code's length.
      deployedMetamorphicContract := create2( // call CREATE2 with 4 arguments.
        0,                                    // do not forward any endowment.
        encoded_data,                         // pass in initialization code.
        encoded_size,                         // pass in init code's length.
        salt                                  // pass in the salt value.
      )
    }

    require(
      deployedMetamorphicContract == metamorphicContractAddress,
      "Failed to deploy the new metamorphic contract."
    );

    if (data.length > 0 || msg.value > 0) {
      (bool success,) = metamorphicContractAddress.call{value:msg.value}(data);
      require(success, "Failed to initialize the new metamorphic contract.");
    }

    emit Metamorphosed(deployedMetamorphicContract, implementationContract);
  }

  function getImplementation() external view returns (address implementation) {
    return _implementations[msg.sender];
  }

  function getImplementationContractAddress(
    address metamorphicContractAddress
  ) external view returns (address implementationContractAddress) {
    return _implementations[metamorphicContractAddress];
  }

  function findMetamorphicContractAddress(
    bytes32 salt
  ) external view returns (address metamorphicContractAddress) {
    metamorphicContractAddress = _getMetamorphicContractAddress(salt);
  }

  function getMetamorphicContractInitializationCode() external view returns (
    bytes memory metamorphicContractInitializationCode
  ) {
    return _metamorphicContractInitializationCode;
  }

  function getMetamorphicContractInitializationCodeHash() external view returns (
    bytes32 metamorphicContractInitializationCodeHash
  ) {
    return _metamorphicContractInitializationCodeHash;
  }

  function _getMetamorphicContractAddress(
    bytes32 salt
  ) internal view returns (address) {
    // determine the address of the metamorphic contract.
    return address(
      uint160(                      // downcast to match the address type.
        uint256(                    // convert to uint to truncate upper digits.
          keccak256(                // compute the CREATE2 hash using 4 inputs.
            abi.encodePacked(       // pack all inputs to the hash together.
              hex"ff",              // start with 0xff to distinguish from RLP.
              address(this),        // this contract will be the caller.
              salt,                 // pass in the supplied salt value.
              _metamorphicContractInitializationCodeHash // the init code hash.
            )
          )
        )
      )
    );
  }
}
