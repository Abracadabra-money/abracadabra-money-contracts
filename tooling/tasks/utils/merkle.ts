import { ethers } from "ethers";
import keccak256 from "keccak256";
import MerkleTree from "merkletreejs";

export const getWhitelistNode = (account: string, amount: string) => {
    return Buffer.from(ethers.solidityPackedKeccak256(['address', 'uint256'], [account, amount]).slice(2), 'hex');
};

/**
 * Example:
 * const merkleTree = createMerkleTree([
 *   [aliceAddress, "1000000000000000000"],
 *   [bobAddress, "2000000000000000000"],
 * ]);
 */
export const createAccountAmountMerkleTree = (items: [string, string][]) => {
    const tree = new MerkleTree(
        items.map((i) => getWhitelistNode(...i)),
        keccak256,
        { sortPairs: true }
    );

    return {
        merkleRoot: tree.getHexRoot(),
        totalAmount: items.reduce((acc, i) => acc + BigInt(i[1]), BigInt(0)).toString(),
        itemCounts: items.length,
        items: items.map((i) => {
            return {
                account: i[0],
                amount: i[1],
                proof: tree.getHexProof(getWhitelistNode(i[0], i[1])),
            };
        }),
    };
};
