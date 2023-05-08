// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;
import "BoringSolidity/BoringOwnable.sol";

contract TestContract is BoringOwnable {
    string public param;

    constructor(string memory _param, address _owner) {
        param = _param;
        owner = _owner;
    }

    function setParam(string memory _param) external onlyOwner {
        param = _param;
    }
}
