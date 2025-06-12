// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

library BLS12_381_LIB {
    uint constant PUBLIC_KEY_LENGTH = 48;
    uint constant SIGNATURE_LENGTH = 96;

    uint8 constant MOD_EXP_PRECOMPILE_ADDRESS = 0x5;
    uint8 constant BLS12_381_G1_ADD_ADDRESS = 0xA;
    uint8 constant BLS12_381_G2_ADD_ADDRESS = 0xD;
    uint8 constant BLS12_381_PAIRING_PRECOMPILE_ADDRESS = 0x10;
    uint8 constant BLS12_381_MAP_FIELD_TO_G2_PRECOMPILE_ADDRESS = 0x12;

    string constant BLS_SIG_DST = "BLS_SIG_BLS12381G2_XMD:SHA-256_SSWU_RO_POP_+";
    bytes1 constant BLS_BYTE_WITHOUT_FLAGS_MASK = bytes1(0x1f);

    // 2**381 - 1
    uint constant decPow381_a = 42535295865117307932921825928971026431;
    uint constant decPow381_b = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    // 2**382 - 1
    uint constant decPow382_a = 85070591730234615865843651857942052863 ;
    uint constant decPow382_b = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    // 2**383 - 1
    uint constant decPow383_a = 170141183460469231731687303715884105727;
    uint constant decPow383_b = 115792089237316195423570985008687907853269984665640564039457584007913129639935;

    // q
    uint constant q1 = 34565483545414906068789196026815425751;
    uint constant q2 = 45442060874369865957053122457065728162598490762543039060009208264153100167851;

    // (q + 1) // 4
    uint constant divQ1 = 8641370886353726517197299006703856437;
    uint constant divQ2 = 98204582146579613056941519370782362930602111189866182794595490071973122271915;

    // Fp is a field element with the high-order part stored in `a`.
    struct Fp {
        uint a;
        uint b;
    }

    // Fp2 is an extension field element with the coefficient of the quadratic non-residue stored in 'b'.
    struct Fp2 {
        Fp a;
        Fp b;
    }

    // G1Point represents a point on BLS12-381 over Fp with coordinates (X, Y).
    struct G1Point {
        Fp X;
        Fp Y;
    }

    // G2Point represents a point on BLS12-381 over Fp2 with coordinates (X, Y).
    struct G2Point {
        Fp2 X;
        Fp2 Y;
    }

    // ---------------------------- Point Mapping ----------------------------
    // Reduce the number encoded as the big-endian slice of data[start:end] modulo the BLS12-381 field modulus.
    function reduceModulo(bytes memory data, uint start, uint end) private view returns (bytes memory) {
        uint length = end - start;
        assert (length >= 0);
        assert (length <= data.length);

        bytes memory result = new bytes(48);

        bool success;
        assembly {
        // First, write BSize, ESize, and MSize
            let p := mload(0x40)
        // write length of base
            mstore(p, length)
        // write length of exponent
            mstore(add(p, 0x20), 0x20)
        // write length of modulus
        // mstore(add(p, 0x40), 48)
            mstore(add(p, 0x40), 0x30)

        // Then, write B, E and M
        // base
            let ctr := length
            let src := add(add(data, 0x20), start)
            let dst := add(p, 0x60)

            for { }
            or(gt(ctr, 0x20), eq(ctr, 0x20))
            { ctr := sub(ctr, 0x20) }
            {
                mstore(dst, mload(src))
                dst := add(dst, 0x20)
                src := add(src, 0x20)
            }

            let mask := sub(exp(256, sub(0x20, ctr)), 1)
            let srcpart := and(mload(src), not(mask))
            let destpart := and(mload(dst), mask)
            mstore(dst, or(destpart, srcpart))

        // exponent
            mstore(add(p, add(0x60, length)), 1)
        // modulus
            let modulusAddr := add(p, add(0x60, add(0x10, length)))
            mstore(modulusAddr, or(mload(modulusAddr), 0x1a0111ea397fe69a4b1ba7b6434bacd7))
            mstore(add(p, add(0x90, length)), 0x64774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab)

            success := staticcall(
            sub(gas(), 2000),
            MOD_EXP_PRECOMPILE_ADDRESS,
            p,
            add(0xB0, length),
            add(result, 0x20),
            48)
        // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success, "call to modular exponentiation precompile failed");
        return result;
    }

    function splitBytes(bytes memory input, bool flag) private pure returns (bytes[] memory) {
        if (flag) {
            require(input.length % 48 == 0, "Invalid length");

            uint256 numChunks = input.length / 48;
            bytes[] memory chunks = new bytes[](numChunks);

            for (uint256 i = 0; i < numChunks; i++) {
                bytes memory chunk = new bytes(48);
                for (uint256 j = 0; j < 48; j++) {
                    chunk[j] = input[i * 48 + j];
                }
                chunks[i] = chunk;
            }

            return chunks;

        } else{
            require(input.length % 96 == 0, "Invalid length");

            uint256 numChunks = input.length / 96;
            bytes[] memory chunks = new bytes[](numChunks);

            for (uint256 i = 0; i < numChunks; i++) {
                bytes memory chunk = new bytes(96);
                for (uint256 j = 0; j < 96; j++) {
                    chunk[j] = input[i * 96 + j];
                }
                chunks[i] = chunk;
            }

            return chunks;
        }
    }

    function sliceToUint(bytes memory data, uint start, uint end) private pure returns (uint) {
        uint length = end - start;
        assert(length >= 0);
        assert(length <= 32);

        uint result;
        for (uint i = 0; i < length; i++) {
            bytes1 b = data[start+i];
            result = result + (uint8(b) * 2**(8*(length-i-1)));
        }
        return result;
    }

    function convertSliceToFp(bytes memory data, uint start, uint end) private view returns (Fp memory) {
        bytes memory fieldElement = reduceModulo(data, start, end);
        uint a = sliceToUint(fieldElement, 0, 16);
        uint b = sliceToUint(fieldElement, 16, 48);
        return Fp(a, b);
    }

    function expandMessage(bytes32 message) public pure returns (bytes memory) {
        bytes memory b0Input = new bytes(143);
        for (uint i = 0; i < 32; i++) {
            b0Input[i+64] = message[i];
        }
        b0Input[96] = 0x01;
        for (uint i = 0; i < 44; i++) {
            b0Input[i+99] = bytes(BLS_SIG_DST)[i];
        }

        bytes32 b0 = sha256(abi.encodePacked(b0Input));

        bytes memory output = new bytes(256);
        bytes32 chunk = sha256(abi.encodePacked(b0, bytes1(0x01), bytes(BLS_SIG_DST)));
        assembly {
            mstore(add(output, 0x20), chunk)
        }
        for (uint i = 2; i < 9; i++) {
            bytes32 input;
            assembly {
                input := xor(b0, mload(add(output, add(0x20, mul(0x20, sub(i, 2))))))
            }
            chunk = sha256(abi.encodePacked(input, bytes1(uint8(i)), bytes(BLS_SIG_DST)));
            assembly {
                mstore(add(output, add(0x20, mul(0x20, sub(i, 1)))), chunk)
            }
        }

        return output;
    }

    function hashToField(bytes32 message) public view returns (Fp2[2] memory result) {
        bytes memory some_bytes = expandMessage(message);
        result[0] = Fp2(
            convertSliceToFp(some_bytes, 0, 64),
            convertSliceToFp(some_bytes, 64, 128)
        );
        result[1] = Fp2(
            convertSliceToFp(some_bytes, 128, 192),
            convertSliceToFp(some_bytes, 192, 256)
        );
    }

    function mapToG2(Fp2 memory fieldElement) public view returns (G2Point memory result) {
        uint[4] memory input;
        input[0] = fieldElement.a.a;
        input[1] = fieldElement.a.b;
        input[2] = fieldElement.b.a;
        input[3] = fieldElement.b.b;

        uint[8] memory output;

        bool success;
        assembly {
            success := staticcall(
            sub(gas(), 2000),
            BLS12_381_MAP_FIELD_TO_G2_PRECOMPILE_ADDRESS,
            input,
            128,
            output,
            256
            )
        // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success, "call to map to curve precompile failed");

        return G2Point(
            Fp2(
                Fp(output[0], output[1]),
                Fp(output[2], output[3])
            ),
            Fp2(
                Fp(output[4], output[5]),
                Fp(output[6], output[7])
            )
        );
    }

    function addG1(G1Point memory pa, G1Point memory pb) private view returns (G1Point memory) {
        uint[8] memory input;
        input[0] = pa.X.a;
        input[1] = pa.X.b;
        input[2] = pa.Y.a;
        input[3] = pa.Y.b;

        input[4] = pb.X.a;
        input[5] = pb.X.b;
        input[6] = pb.Y.a;
        input[7] = pb.Y.b;

        uint[4] memory output;

        bool success;
        assembly {
            success := staticcall(
            sub(gas(), 2000),
            BLS12_381_G1_ADD_ADDRESS,
            input,
            256,
            output,
            128
            )
        // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }

        require(success, "g1 add precompile failed");
        return G1Point(
            Fp(output[0], output[1]),
            Fp(output[2], output[3])
        );
    }

    function addG2(G2Point memory a, G2Point memory b) private view returns (G2Point memory) {
        uint[16] memory input;
        input[0]  = a.X.a.a;
        input[1]  = a.X.a.b;
        input[2]  = a.X.b.a;
        input[3]  = a.X.b.b;
        input[4]  = a.Y.a.a;
        input[5]  = a.Y.a.b;
        input[6]  = a.Y.b.a;
        input[7]  = a.Y.b.b;

        input[8]  = b.X.a.a;
        input[9]  = b.X.a.b;
        input[10] = b.X.b.a;
        input[11] = b.X.b.b;
        input[12] = b.Y.a.a;
        input[13] = b.Y.a.b;
        input[14] = b.Y.b.a;
        input[15] = b.Y.b.b;

        uint[8] memory output;

        bool success;
        assembly {
            success := staticcall(
            sub(gas(), 2000),
            BLS12_381_G2_ADD_ADDRESS,
            input,
            512,
            output,
            256
            )
        // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success, "call to addition in G2 precompile failed");

        return G2Point(
            Fp2(
                Fp(output[0], output[1]),
                Fp(output[2], output[3])
            ),
            Fp2(
                Fp(output[4], output[5]),
                Fp(output[6], output[7])
            )
        );
    }

    // Implements "hash to the curve" from the IETF BLS draft.
    function hashToCurve(bytes32 message) public view returns (G2Point memory) {
        Fp2[2] memory messageElementsInField = hashToField(message);
        G2Point memory firstPoint = mapToG2(messageElementsInField[0]);
        G2Point memory secondPoint = mapToG2(messageElementsInField[1]);
        return addG2(firstPoint, secondPoint);
    }

    // ------------------ BLS Signature ------------------
    // Aggregate pubkey slices
    function pubkeyAggregate(bytes[] memory pubkeySlices, bytes[] memory pubkeyYSlices) public view returns (G1Point memory){
        require(pubkeySlices.length == pubkeyYSlices.length);
        Fp memory pubkeyYCoordinate = Fp(sliceToUint(pubkeyYSlices[0], 0, 16), sliceToUint(pubkeyYSlices[0], 16, 48));
        G1Point memory aggPubkey = decodeG1Point(pubkeySlices[0], pubkeyYCoordinate);

        for (uint i = 1; i < pubkeySlices.length; i++){
            pubkeyYCoordinate = Fp(sliceToUint(pubkeyYSlices[i], 0, 16), sliceToUint(pubkeyYSlices[i], 16, 48));
            aggPubkey = addG1(aggPubkey, decodeG1Point(pubkeySlices[i], pubkeyYCoordinate));
        }

        return aggPubkey;
    }

    // Aggregate signature slices
    function signatureAggregate(bytes[] memory signatureSlices, bytes[] memory signatureYSlices) public view returns (G2Point memory) {
        require(signatureSlices.length == signatureYSlices.length);
        Fp2 memory signatureYCoordinate = Fp2(
            Fp(sliceToUint(signatureYSlices[0], 48, 64), sliceToUint(signatureYSlices[0], 64, 96)),
            Fp(sliceToUint(signatureYSlices[0], 0, 16), sliceToUint(signatureYSlices[0], 16, 48))
        );

        G2Point memory aggSignature = decodeG2Point(signatureSlices[0], signatureYCoordinate);
        for (uint i = 1; i < signatureSlices.length; i++){
            signatureYCoordinate = Fp2(
                Fp(sliceToUint(signatureYSlices[i], 48, 64), sliceToUint(signatureYSlices[i], 64, 96)),
                Fp(sliceToUint(signatureYSlices[i], 0, 16), sliceToUint(signatureYSlices[i], 16, 48))
            );
            aggSignature = addG2(aggSignature, decodeG2Point(signatureSlices[i], signatureYCoordinate));
        }

        return aggSignature;
    }

    function decodeG1Point(bytes memory encodedX, Fp memory Y) private pure returns (G1Point memory) {
        encodedX[0] = encodedX[0] & BLS_BYTE_WITHOUT_FLAGS_MASK;
        uint a = sliceToUint(encodedX, 0, 16);
        uint b = sliceToUint(encodedX, 16, 48);
        Fp memory X = Fp(a, b);
        return G1Point(X,Y);
    }

    function decodeG2Point(bytes memory encodedX, Fp2 memory Y) private pure returns (G2Point memory) {
        encodedX[0] = encodedX[0] & BLS_BYTE_WITHOUT_FLAGS_MASK;
        // NOTE: the "flag bits" of the second half of `encodedX` are always == 0x0

        uint aa = sliceToUint(encodedX, 48, 64);
        uint ab = sliceToUint(encodedX, 64, 96);
        uint ba = sliceToUint(encodedX, 0, 16);
        uint bb = sliceToUint(encodedX, 16, 48);
        Fp2 memory X = Fp2(
            Fp(aa, ab),
            Fp(ba, bb)
        );
        return G2Point(X, Y);
    }

    function blsPairingCheck(G1Point memory publicKey, G2Point memory messageOnCurve, G2Point memory signature) public view returns (bool) {
        uint[24] memory input;

        input[0] =  publicKey.X.a;
        input[1] =  publicKey.X.b;
        input[2] =  publicKey.Y.a;
        input[3] =  publicKey.Y.b;

        input[4] =  messageOnCurve.X.a.a;
        input[5] =  messageOnCurve.X.a.b;
        input[6] =  messageOnCurve.X.b.a;
        input[7] =  messageOnCurve.X.b.b;
        input[8] =  messageOnCurve.Y.a.a;
        input[9] =  messageOnCurve.Y.a.b;
        input[10] = messageOnCurve.Y.b.a;
        input[11] = messageOnCurve.Y.b.b;

        // NOTE: this constant is -P1, where P1 is the generator of the group G1.
        input[12] = 31827880280837800241567138048534752271;
        input[13] = 88385725958748408079899006800036250932223001591707578097800747617502997169851;
        input[14] = 22997279242622214937712647648895181298;
        input[15] = 46816884707101390882112958134453447585552332943769894357249934112654335001290;

        input[16] =  signature.X.a.a;
        input[17] =  signature.X.a.b;
        input[18] =  signature.X.b.a;
        input[19] =  signature.X.b.b;
        input[20] =  signature.Y.a.a;
        input[21] =  signature.Y.a.b;
        input[22] =  signature.Y.b.a;
        input[23] =  signature.Y.b.b;

        uint[1] memory output;

        bool success;
        assembly {
            success := staticcall(
            sub(gas(), 2000),
            BLS12_381_PAIRING_PRECOMPILE_ADDRESS,
            input,
            768,
            output,
            32
            )
        // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success, "call to pairing precompile failed");

        return output[0] == 1;
    }

    function blsSignatureIsValid(
        bytes32 message,
        bytes memory encodedPublicKey,
        bytes memory encodedSignature,
        bytes memory encodedPublicKeyYCoordinate,
        bytes memory encodedSignatureYCoordinate
    ) public view returns (bool) {
        // Decode signature
        G2Point memory signature;
        if (encodedSignature.length == SIGNATURE_LENGTH) {
            Fp2 memory signatureYCoordinate = Fp2(
                Fp(sliceToUint(encodedSignatureYCoordinate, 48, 64), sliceToUint(encodedSignatureYCoordinate, 64, 96)),
                Fp(sliceToUint(encodedSignatureYCoordinate, 0, 16), sliceToUint(encodedSignatureYCoordinate, 16, 48))
            );
            G2Point memory signature = decodeG2Point(encodedSignature, signatureYCoordinate);
        } else {
            bytes[] memory signatureSlices = splitBytes(encodedSignature, false);
            bytes[] memory signatureYSlices = splitBytes(encodedSignatureYCoordinate, false);
            signature = signatureAggregate(signatureSlices, signatureYSlices);
        }

        // Decode message
        G2Point memory messageOnCurve = hashToCurve(message);

        // Decode pubkey
        G1Point memory publicKey;
        if (encodedPublicKey.length == PUBLIC_KEY_LENGTH) {
            Fp memory publicKeyYCoordinate = Fp(sliceToUint(encodedPublicKeyYCoordinate, 0, 16), sliceToUint(encodedPublicKeyYCoordinate, 16, 48));
            publicKey = decodeG1Point(encodedPublicKey, publicKeyYCoordinate);
        } else {
            bytes[] memory pubkeySlices = splitBytes(encodedPublicKey, true);
            bytes[] memory pubkeyYSlices = splitBytes(encodedPublicKeyYCoordinate, true);
            publicKey = pubkeyAggregate(pubkeySlices, pubkeyYSlices);
        }

        // Pairing check
        return blsPairingCheck(publicKey, messageOnCurve, signature);
    }

}
