// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

library BLS12_381Lib {

    uint8 constant BLS12_381_PAIRING_PRECOMPILE_ADDRESS = 0x10;
    // Fp is a field element with the high-order part stored in `a`.
    struct Fp {
        uint a;
        uint b;
    }

    // Fp2 is an extension field element with the coefficient of the
    // quadratic non-residue stored in `b`, i.e. p = a + i * b
    struct Fp2 {
        Fp a;
        Fp b;
    }

    struct G1Point{
        Fp X;
        Fp Y;
    }

    struct G2Point{
        Fp2 X;
        Fp2 Y;
    }

    function blsPairingCheck(G1Point memory g1PK, G2Point memory g2Msg, G2Point memory g2SIG) public view returns(bool){
        uint[24] memory input;

        input[0] =  g1PK.X.a;
        input[1] =  g1PK.X.b;
        input[2] =  g1PK.Y.a;
        input[3] =  g1PK.Y.b;

        input[4] =  g2Msg.X.a.a;
        input[5] =  g2Msg.X.a.b;
        input[6] =  g2Msg.X.b.a;
        input[7] =  g2Msg.X.b.b;
        input[8] =  g2Msg.Y.a.a;
        input[9] =  g2Msg.Y.a.b;
        input[10] = g2Msg.Y.b.a;
        input[11] = g2Msg.Y.b.b;

        // NOTE: this constant is -P1, where P1 is the generator of the group G1.
        input[12] = 31827880280837800241567138048534752271;
        input[13] = 88385725958748408079899006800036250932223001591707578097800747617502997169851;
        input[14] = 22997279242622214937712647648895181298;
        input[15] = 46816884707101390882112958134453447585552332943769894357249934112654335001290;

        input[16] =  g2SIG.X.a.a;
        input[17] =  g2SIG.X.a.b;
        input[18] =  g2SIG.X.b.a;
        input[19] =  g2SIG.X.b.b;
        input[20] =  g2SIG.Y.a.a;
        input[21] =  g2SIG.Y.a.b;
        input[22] =  g2SIG.Y.b.a;
        input[23] =  g2SIG.Y.b.b;

        uint[1] memory output;

        assembly {
            if iszero(staticcall(gas(), BLS12_381_PAIRING_PRECOMPILE_ADDRESS, add(input, 0x20), 768, output, 32)){
                revert(0, 0)
            }
        }

        return output[0] == 1;

    }
    
}
