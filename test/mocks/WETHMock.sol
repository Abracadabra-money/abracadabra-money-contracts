// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20Mock} from "./ERC20Mock.sol";

contract WETHMock is ERC20Mock {
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);

    constructor(string memory name, string memory symbol) ERC20Mock(name, symbol) {}

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);

        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) public {
        _burn(msg.sender, wad);

        payable(msg.sender).transfer(wad);

        emit Withdrawal(msg.sender, wad);
    }
}
