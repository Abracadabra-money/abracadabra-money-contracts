const stringifyReplacer = (_, value) => (value === undefined ? null : value);

const serializeJSONObject = (json) => {
    if (Array.isArray(json)) {
        return `[${json.map((el) => serializeJSONObject(el)).join(',')}]`;
    }

    if (typeof json === 'object' && json !== null) {
        let acc = '';
        const keys = Object.keys(json).sort();
        acc += `{${JSON.stringify(keys, stringifyReplacer)}`;

        for (let i = 0; i < keys.length; i++) {
            acc += `${serializeJSONObject(json[keys[i]])},`;
        }

        return `${acc}}`;
    }

    return `${JSON.stringify(json, stringifyReplacer)}`;
};

const calculateChecksum = (ethers, batchFile) => {
    const serialized = serializeJSONObject({
        ...batchFile,
        meta: { ...batchFile.meta, name: null },
    });
    const sha = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(serialized));

    return sha || undefined;
};

module.exports = {
    calculateChecksum
};