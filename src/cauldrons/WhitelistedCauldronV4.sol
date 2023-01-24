// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;
import "cauldrons/CauldronV4.sol";
import "interfaces/IWhitelister.sol";
import "BoringSolidity/libraries/BoringRebase.sol";

contract WhitelistedCauldronV4 is CauldronV4 {
    using RebaseLibrary for Rebase;

    // whitelister
    IWhitelister public whitelister;

    uint8 internal constant ACTION_SET_MAX_BORROW = 31;

    constructor (IBentoBoxV1 bentoBox_, IERC20 magicInternetMoney_) CauldronV4 (bentoBox_, magicInternetMoney_) {

    }

    event LogChangeWhitelister(IWhitelister indexed newWhiteLister);

    function _preBorrowAction(address, uint256, uint256 newBorrowPart, uint256) internal view override {
        require(whitelister == IWhitelister(address(0)) || whitelister.getBorrowStatus(msg.sender, newBorrowPart), "Whitelisted borrow exceeded");
    }

    function _additionalCookAction(
        uint8 action,
        uint256, /*value*/
        bytes memory data,
        uint256, /*value1*/
        uint256 /*value2*/
    ) internal virtual override returns (bytes memory, uint8) {
        if (action == ACTION_SET_MAX_BORROW) {
            (address user, uint256 maxBorrow, bytes32[] memory merkleProof) = abi.decode(data, (address, uint256, bytes32[]));
            whitelister.setMaxBorrow(user, maxBorrow, merkleProof);
        }
    }

    /// @notice allows to change the whitelister
    /// @param newWhiteLister new whitelisting address
    function changeWhitelister(IWhitelister newWhiteLister) public onlyMasterContractOwner {
        whitelister = newWhiteLister;
        emit LogChangeWhitelister(newWhiteLister);
    }

}