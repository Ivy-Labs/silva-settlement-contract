// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

interface ISilvaOneStepVM {
    function oneStep(uint256 step, bytes32 before, bytes calldata proof) external view returns (bytes32 afterr);
}