import { ethers } from "ethers";

const stringifyReplacer = (_: any, value: any) => (value === undefined ? null : value);

const serializeJSONObject = (json: any): string => {
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

export const calculateChecksum = (batchFile: any): string | undefined => {
    const serialized = serializeJSONObject({
        ...batchFile,
        meta: { ...batchFile.meta, name: null },
    });
    const sha = ethers.keccak256(ethers.toUtf8Bytes(serialized));

    return sha || undefined;
};