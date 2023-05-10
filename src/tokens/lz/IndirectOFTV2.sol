// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "tokens/lz/BaseOFTV2.sol";
import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "interfaces/IMintableBurnable.sol";

contract IndirectOFTV2 is BaseOFTV2 {
    using SafeERC20 for IERC20;
    IMintableBurnable internal immutable mintBurn;
    IERC20 internal immutable innerToken;
    uint internal immutable ld2sdRate;

    constructor(
        address _token,
        IMintableBurnable _mintBurn,
        uint8 _sharedDecimals,
        address _lzEndpoint
    ) BaseOFTV2(_sharedDecimals, _lzEndpoint) {
        innerToken = IERC20(_token);
        mintBurn = _mintBurn;

        (bool success, bytes memory data) = _token.staticcall(abi.encodeWithSignature("decimals()"));
        require(success, "IndirectOFT: failed to get token decimals");
        uint8 decimals = abi.decode(data, (uint8));

        require(_sharedDecimals <= decimals, "IndirectOFT: sharedDecimals must be <= decimals");
        ld2sdRate = 10 ** (decimals - _sharedDecimals);
    }

    /************************************************************************
     * public functions
     ************************************************************************/
    function circulatingSupply() public view virtual override returns (uint) {
        return innerToken.totalSupply();
    }

    function token() public view virtual override returns (address) {
        return address(innerToken);
    }

    /************************************************************************
     * internal functions
     ************************************************************************/
    function _debitFrom(address _from, uint16, bytes32, uint _amount) internal virtual override returns (uint) {
        require(_from == _msgSender(), "IndirectOFT: owner is not send caller");

        mintBurn.burn(_from, _amount);

        return _amount;
    }

    function _creditTo(uint16, address _toAddress, uint _amount) internal virtual override returns (uint) {
        // tokens are already in this contract, so no need to transfer
        if (_toAddress == address(this)) {
            return _amount;
        }

        mintBurn.mint(_toAddress, _amount);

        return _amount;
    }

    function _ld2sdRate() internal view virtual override returns (uint) {
        return ld2sdRate;
    }
}