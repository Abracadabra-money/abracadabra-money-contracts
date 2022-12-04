// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/ERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "BoringSolidity/libraries/BoringERC20.sol";
import "interfaces/ICauldronV4.sol";
import "interfaces/IMimCauldronDistributor.sol";

contract MimCauldronDistributor is BoringOwnable, IMimCauldronDistributor {
    event LogPaused(bool previous, bool current);
    event LogCauldronParameterChanged(ICauldronV4 indexed cauldron, uint256 targetApy);

    error ErrPaused();
    error ErrInvalidTargetApy(uint16);

    struct CauldronInfo {
        ICauldronV4 cauldron;
        uint16 targetApyInBips;
        uint256 apyCollateralShareValueCache;
        IOracle oracle;
        bytes oracleData;
    }

    uint256 public constant BIPS = 10_000;

    ERC20 public immutable mim;
    CauldronInfo[] public cauldronInfos;
    bool public paused;

    modifier notPaused() {
        if (paused) {
            revert ErrPaused();
        }
        _;
    }

    constructor(ERC20 _mim) {
        mim = _mim;
    }

    function setCauldronParameters(ICauldronV4 _cauldron, uint16 _targetApyInBips) external onlyOwner {
        if (_targetApyInBips > BIPS) {
            revert ErrInvalidTargetApy(_targetApyInBips);
        }

        int256 index = _findCauldronInfo(_cauldron);

        if (index >= 0) {
            if (_targetApyInBips > 0) {
                cauldronInfos[uint256(index)].targetApyInBips = _targetApyInBips;
            } else {
                cauldronInfos[uint256(index)] = cauldronInfos[cauldronInfos.length - 1];
                cauldronInfos.pop();
            }
        } else {
            cauldronInfos.push(
                CauldronInfo({
                    cauldron: _cauldron,
                    targetApyInBips: _targetApyInBips,
                    oracle: _cauldron.oracle(),
                    oracleData: _cauldron.oracleData(),
                    apyCollateralShareValueCache: 0
                })
            );
        }

        emit LogCauldronParameterChanged(_cauldron, _targetApyInBips);
    }

    function getCauldronInfo(ICauldronV4 _cauldron) external view returns (CauldronInfo memory) {
        return cauldronInfos[uint256(_findCauldronInfo(_cauldron))];
    }

    function _findCauldronInfo(ICauldronV4 _cauldron) private view returns (int256) {
        for (uint256 i = 0; i < cauldronInfos.length; i++) {
            if (cauldronInfos[i].cauldron == _cauldron) {
                return int256(i);
            }
        }

        return -1;
    }

    // take % apy on the collateral share and compute USD value with oracle
    // then take this amount and how much that is on the sum of all cauldron'S apy USD

    function distribute() public {
        uint256 amount = mim.balanceOf(address(this));
        uint256 allCauldronsTotalCollateralShareValue = 0;

        // Gather all stats needed for the subsequent distribution
        for (uint256 i = 0; i < cauldronInfos.length; i++) {
            CauldronInfo storage info = cauldronInfos[i];

            // compute the cauldron's total collateral share value in usd
            //
            // TODO: could we have the average oracle price from last distribution to now? Otherwise a cauldron
            // might get more or less depending on the current market condition at distribution time.
            uint256 totalCollateralShareValue = (info.cauldron.totalCollateralShare() * 1e18) / info.oracle.peekSpot(info.oracleData);

            // how many USD represents the target apy
            info.apyCollateralShareValueCache = (info.targetApyInBips * totalCollateralShareValue) / BIPS;

            // sum all target usd apy
            allCauldronsTotalCollateralShareValue += info.apyCollateralShareValueCache;
        }

        for (uint256 i = 0; i < cauldronInfos.length; i++) {
            CauldronInfo storage info = cauldronInfos[i];

            // what's the amount to distribute
            uint256 distributionAmount = (info.apyCollateralShareValueCache * 1e18) / allCauldronsTotalCollateralShareValue;

            if (distributionAmount > amount) {
                distributionAmount = amount;
            }

            if (distributionAmount > 0) {
                Rebase memory totalBorrow = info.cauldron.totalBorrow();
                if (distributionAmount > totalBorrow.elastic) {
                    distributionAmount = totalBorrow.elastic;
                }

                mim.transfer(address(info.cauldron), distributionAmount);

                info.cauldron.repayForAll(0, true);

                amount -= distributionAmount;
            }
        }
    }

    function setPaused(bool _paused) external onlyOwner {
        emit LogPaused(paused, _paused);
        paused = _paused;
    }

    function withdraw() external onlyOwner {
        mim.transfer(owner, mim.balanceOf(address(this)));
    }
}
