// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "utils/BaseScript.sol";
import {TokenLocker} from "/periphery/TokenLocker.sol";
import {IOwnableOperators} from "/interfaces/IOwnableOperators.sol";
import {MintableBurnableUpgradeableERC20} from "/tokens/MintableBurnableUpgradeableERC20.sol";
import {TokenLocker} from "/periphery/TokenLocker.sol";

bytes32 constant BSPELL_SALT = keccak256(bytes("bSpell-1727108300"));
bytes32 constant BSPELL_LOCKER_SALT = keccak256(bytes("bSpellLocker-1727108300"));

contract BoundSpellScript is BaseScript {
    function deploy() public returns (TokenLocker bSpellLocker) {
        address safe = toolkit.getAddress("safe.ops");
        address yieldSafe = toolkit.getAddress("safe.yields");

        vm.startBroadcast();

        address bspell = address(
            deployUpgradeableUsingCreate3(
                "BSPELL",
                BSPELL_SALT,
                "MintableBurnableUpgradeableERC20.sol:MintableBurnableUpgradeableERC20",
                "",
                abi.encodeCall(MintableBurnableUpgradeableERC20.initialize, ("boundSPELL", "bSPELL", 18, tx.origin))
            )
        );

        if (block.chainid == ChainId.Arbitrum) {
            address spell = toolkit.getAddress("spellV2");

            bSpellLocker = TokenLocker(
                deployUpgradeableUsingCreate3(
                    "BSPELLLocker",
                    BSPELL_LOCKER_SALT,
                    "TokenLocker.sol:TokenLocker",
                    abi.encode(bspell, spell, 13 weeks),
                    abi.encodeCall(TokenLocker.initialize, (tx.origin))
                )
            );

            TokenLocker.InstantRedeemParams memory params = TokenLocker.InstantRedeemParams({
                immediateBips: 5000, // 50%
                burnBips: 3000, // 30%
                // fee goes to the gnosis safe yields, which will approve bSPELL
                // to the MultiRewardsDistributor contract to distribute back to
                // the staking contract
                feeCollector: yieldSafe
            });

            bSpellLocker.updateInstantRedeemParams(params);

            if (IOwnableOperators(bspell).owner() == tx.origin) {
                IOwnableOperators(bspell).setOperator(address(bSpellLocker), true);
            }

            if (!testing()) {
                bSpellLocker.transferOwnership(safe);
            }
        }

        if (!testing()) {
            //IOwnableOperators(bspell).transferOwnership(safe);
        }

        vm.stopBroadcast();
    }
}
