const shell = require('shelljs');
const fs = require("fs");
const toolkit = require('./utils/toolkit');
const { basename } = require('path');

module.exports = async function (taskArgs) {
    const items = [];

    console.log(`Processing ${taskArgs.cvs}...`);

    fs.readFileSync(taskArgs.cvs, 'utf8').split(/\r?\n/).forEach(async function (line) {
        if (line) {
            const [address, amount] = line.split(';');
            items.push([address.trim(), amount.trim()]);
        }
    });

    console.log(`Creating merkle tree...`);
    const tree = toolkit.createAccountAmountMerkleTree(items);
    const json = JSON.stringify(tree, null, 4);
    console.log(json);
    const out = `${basename(taskArgs.cvs, '.csv')}.proofs.json`;
    fs.writeFileSync(out, json, 'utf8');
    console.log(`Merkle tree saved to ${out}`);

}