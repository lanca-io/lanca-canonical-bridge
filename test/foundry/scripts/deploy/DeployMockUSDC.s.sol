// SPDX-License-Identifier: UNLICENSED
/**
 * @title Security Reporting
 * @notice If you discover any security vulnerabilities, please report them responsibly.
 * @contact email: security@concero.io
 */
pragma solidity 0.8.28;

import {Script} from "forge-std/src/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    uint8 private _decimals;
    address private _minter;

    modifier onlyMinter() {
        require(msg.sender == _minter, "FiatToken: caller is not the masterMinter");
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimalsValue,
        address minter
    ) ERC20(name, symbol) {
        _decimals = decimalsValue;
        _minter = minter;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function burn(uint256 amount) external onlyMinter {
        _burn(msg.sender, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}

contract DeployMockUSDC is Script {
    address public initialHolder = vm.envAddress("PROXY_DEPLOYER_ADDRESS");

    function deployUSDC(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) public returns (MockERC20) {
        MockERC20 token = new MockERC20(name, symbol, decimals, initialHolder);

        return token;
    }
}
