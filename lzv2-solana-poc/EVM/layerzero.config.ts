import { EndpointId } from '@layerzerolabs/lz-definitions'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

const arbitrumSepoliaOFTContract: OmniPointHardhat = {
    eid: EndpointId.ARBSEP_V2_TESTNET,
    contractName: 'LZV2OFT',
}

const config: OAppOmniGraphHardhat = {
    contracts: [
        {
            contract: arbitrumSepoliaOFTContract,
        },
    ],
    connections: [
    ],
}

export default config
