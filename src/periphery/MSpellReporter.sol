// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.10;
import "BoringSolidity/BoringOwnable.sol";
import "libraries/BokkyPooBahsDateTimeLibrary.sol"; // Thank you Bokky
import "BoringSolidity/libraries/BoringERC20.sol";

interface ILayerZeroEndpoint {
    // @notice send a LayerZero message to the specified address at a LayerZero endpoint.
    // @param _dstChainId - the destination chain identifier
    // @param _destination - the address on destination chain (in bytes). address length/format may vary by chains
    // @param _payload - a custom bytes payload to send to the destination contract
    // @param _refundAddress - if the source transaction is cheaper than the amount of value passed, refund the additional amount to this address
    // @param _zroPaymentAddress - the address of the ZRO token holder who would pay for the transaction
    // @param _adapterParams - parameters for custom functionality. e.g. receive airdropped native gas from the relayer on destination
    function send(uint16 _dstChainId, bytes calldata _destination, bytes calldata _payload, address payable _refundAddress, address _zroPaymentAddress, bytes calldata _adapterParams) external payable;
}

contract mSpellReporter is BoringOwnable {
    using BoringERC20 for IERC20;
    ILayerZeroEndpoint private immutable endpoint;
    uint16 private constant destChain = 1;
    address private constant refund = 0xfddfE525054efaAD204600d00CA86ADb1Cc2ea8a;
    IERC20 public immutable SPELL;
    address public immutable mSpell;
    address public mSpellSender;
    uint256 public lastUpdated;

    constructor (ILayerZeroEndpoint _endpoint, IERC20 _SPELL, address _mSpell){
        SPELL = _SPELL;
        mSpell = _mSpell;
        endpoint = _endpoint;
    }

    error NotNoon();

    modifier onlyNoon {
        uint256 hour = block.timestamp / 1 hours % 24;
        if (hour != 12) {
            revert NotNoon();
        }
        _;
    }

    function changeMSpellSender(address mSpellSender_) external onlyOwner {
        mSpellSender = mSpellSender_;
    }

    function withdraw() external {
        require(msg.sender == refund);
        // get the amount of Ether stored in this contract
        uint amount = address(this).balance;

        // send all Ether to owner
        // Owner can receive Ether since the address of owner is payable
        (bool success, ) = refund.call{value: amount}("");
        require(success, "Failed to send Ether");
    }

    function sendAmount () external onlyNoon {
        require(BokkyPooBahsDateTimeLibrary.getDay(lastUpdated) < BokkyPooBahsDateTimeLibrary.getDay(block.timestamp) 
        || BokkyPooBahsDateTimeLibrary.getMonth(lastUpdated) < BokkyPooBahsDateTimeLibrary.getMonth(block.timestamp) 
        || BokkyPooBahsDateTimeLibrary.getYear(lastUpdated) < BokkyPooBahsDateTimeLibrary.getYear(block.timestamp)
        );
        uint256 weekDay = BokkyPooBahsDateTimeLibrary.getDayOfWeek(block.timestamp);
        require(weekDay == 1 || weekDay == 3 || weekDay == 5);
        uint128 amount = uint128(SPELL.balanceOf(mSpell));
        bytes memory payload = abi.encode(uint32(block.timestamp), amount);

        endpoint.send{value: address(this).balance} (
            destChain,
            abi.encodePacked(mSpellSender, address(this)),
            payload,
            payable(this),
            address(0),
            bytes("")
        );

        lastUpdated = block.timestamp;
    }
    fallback() external payable {}
    receive() external payable {}
}