const { BigNumber } = require("ethers");

const WAD = BigNumber.from("1000000000000000000");

const _findByKey = (configSection, key) => configSection.find((a) => a.key === key);

const getAddress = (config, name, defaultValue) => {
    const item = _findByKey(config.addresses, name);

    if (item === undefined) {
        if (defaultValue !== undefined) {
            return defaultValue;
        }

        console.log(`No address for '${name}' found`);
        process.exit(1);
    }

    return item.value;
}

const getCauldron = (config, name) => {
    const item = _findByKey(config.cauldrons, name);

    if (!item) {
        console.log(`Cauldron ${cauldron} doesn't exist `);
        console.log("Available cauldrons:");
        for (const cauldron of config.cauldrons) {
            console.log(`- ${cauldron.key}`);
        }
        process.exit(1);
    }

    return item;
}

module.exports = {
    getAddress,
    getCauldron,
    WAD
}