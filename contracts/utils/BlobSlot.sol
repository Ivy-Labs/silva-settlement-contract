// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

library BlobSlot {
    uint256 internal constant BLS_MODULUS = 52435875175126190479447740508185965837690552500527637822603658699938581184513;
    uint256 internal constant PRIMITIVE_ROOT_OF_UNITY = 10238227357739495823651030575849232062558860180284477541189508159991286009131;
    struct Element {
        uint index;
        bytes32 value;
    }

    struct KZGProof {
        bytes32 vHash;
        bytes2 z;
        bytes commitment;
        bytes proof;
    }

    function modExp256(
        uint256 b,
        uint256 e,
        uint256 m
    ) internal view returns (uint256) {
        bytes memory modExpInput = abi.encode(32, 32, 32, b, e, m);
        (bool modexpSuccess, bytes memory modExpOutput) = address(0x05).staticcall(modExpInput);
        require(modexpSuccess, "MODEXP_FAILED");
        require(modExpOutput.length == 32, "MODEXP_WRONG_LENGTH");
        return uint256(bytes32(modExpOutput));
    }

    
    function verifyBlobSlot(Element memory element, KZGProof memory kzg) external view {
        // call pre-compiled contract at 0x0a
        bytes memory input = abi.encodePacked(kzg.vHash, element.value, kzg.z, kzg.commitment, kzg.proof);

        (bool success, bytes memory kzgParams) = address(0x0a).staticcall(input);
        
        (uint256 fieldElementsPerBlob, uint256 blsModulus) = abi.decode(kzgParams, (uint256, uint256));
        require(success && blsModulus == BLS_MODULUS, "IVALID_KZG_PROOF");
        // compute value z
        uint256 bitReversedIndex = 0;
        uint256 tmp = element.index;
        // preimageOffset was required to be 32 byte aligned above
        for (uint256 i = 1; i < fieldElementsPerBlob; i <<= 1) {
            bitReversedIndex <<= 1;
            if (tmp & 1 == 1) {
                bitReversedIndex |= 1;
            }
            tmp >>= 1;
        }
        uint256 rootOfUnityPower = (1 << 32) / fieldElementsPerBlob;
        // Then, we raise the root of unity to the power of bitReversedIndex,
        // to retrieve this word of the KZG commitment.
        rootOfUnityPower *= bitReversedIndex;
        // z is the point the polynomial is evaluated at to retrieve this word of data
        uint256 z = modExp256(PRIMITIVE_ROOT_OF_UNITY, rootOfUnityPower, BLS_MODULUS);
        require(bytes32(z) == kzg.z, "INVALID_INDEX");
    }

}