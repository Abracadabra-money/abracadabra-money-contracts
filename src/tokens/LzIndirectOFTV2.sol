// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "tokens/LzBaseOFTV2.sol";
import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "interfaces/IMintableBurnable.sol";

contract LzIndirectOFTV2 is LzBaseOFTV2 {
    using SafeERC20 for IERC20;
    address public immutable innerToken;
    uint public immutable ld2sdRate;

    constructor(address _innerToken, uint8 _sharedDecimals, address _lzEndpoint) LzBaseOFTV2(_sharedDecimals, _lzEndpoint) {
        innerToken = _innerToken;

        (bool success, bytes memory data) = _innerToken.staticcall(abi.encodeWithSignature("decimals()"));
        require(success, "IndirectOFT: failed to get token decimals");
        uint8 decimals = abi.decode(data, (uint8));

        require(_sharedDecimals <= decimals, "IndirectOFT: sharedDecimals must be <= decimals");
        ld2sdRate = 10 ** (decimals - _sharedDecimals);
    }

    /************************************************************************
     * public functions
     ************************************************************************/
    function circulatingSupply() public view virtual override returns (uint) {
        return IERC20(innerToken).totalSupply();
    }

    function token() public view virtual override returns (address) {
        return innerToken;
    }

    /************************************************************************
     * internal functions
     ************************************************************************/
    function _debitFrom(address _from, uint16, bytes32, uint _amount) internal virtual override returns (uint) {
        require(_from == _msgSender(), "IndirectOFT: owner is not send caller");

        IMintableBurnable(innerToken).burn(_from, _amount);

        return _amount;
    }

    function _creditTo(uint16, address _toAddress, uint _amount) internal virtual override returns (uint) {
        IMintableBurnable(innerToken).mint(_toAddress, _amount);

        return _amount;
    }

    function _ld2sdRate() internal view virtual override returns (uint) {
        return ld2sdRate;
    }
}
