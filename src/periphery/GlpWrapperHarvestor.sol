// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "OpenZeppelin/utils/Address.sol";
import "interfaces/IGmxGlpRewardHandler.sol";
import "interfaces/IMimCauldronDistributor.sol";

contract GlpWrapperHarvestor is BoringOwnable {
    using Address for address;
    event OperatorChanged(address indexed, bool);
    event DistributorChanged(IMimCauldronDistributor indexed, IMimCauldronDistributor indexed);
    error NotAllowedOperator();

    IGmxGlpRewardHandler public immutable wrapper;

    IMimCauldronDistributor public distributor;
    mapping(address => bool) public operators;
    uint64 public lastExecution;

    modifier onlyOperators() {
        if (!operators[msg.sender]) {
            revert NotAllowedOperator();
        }
        _;
    }

    constructor(IGmxGlpRewardHandler _wrapper, IMimCauldronDistributor _distributor) {
        operators[msg.sender] = true;

        wrapper = _wrapper;
        distributor = _distributor;
    }

    function run(
        uint256 amountOutMin,
        IERC20 rewardToken,
        IERC20 outputToken,
        bytes calldata data
    ) external onlyOperators {
        wrapper.harvest();
        wrapper.swapRewards(amountOutMin, rewardToken, outputToken, address(distributor), data);
        distributor.distribute();
        lastExecution = uint64(block.timestamp);
    }

    function setDistributor(IMimCauldronDistributor _distributor) external onlyOwner {
        emit DistributorChanged(distributor, _distributor);
        distributor = _distributor;
    }

    function setOperator(address operator, bool status) external onlyOwner {
        operators[operator] = status;
        emit OperatorChanged(operator, status);
    }
}
