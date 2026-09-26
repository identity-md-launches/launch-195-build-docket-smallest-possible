// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Docket} from "../src/Docket.sol";
import {TestBase} from "./helpers/TestBase.sol";

/// @dev Snapshots exclude fixture/payload construction and transaction intrinsic gas.
contract DocketGasTest is TestBase {
    Docket private fresh;
    Docket private uncommented;
    Docket private existing;

    function setUp() public {
        fresh = new Docket();
        uncommented = new Docket();
        uncommented.createIdea("seed", "seed");
        existing = new Docket();
        existing.createIdea("seed", "seed");
        existing.comment(1, "seed");
    }

    function testGasCreateSmall() public {
        _create(1, 1);
    }

    function testGasCreateTypical() public {
        _create(40, 500);
    }

    function testGasCreateMaximum() public {
        _create(120, 4000);
    }

    function testGasCommentSmallFirst() public {
        _comment(false, 1);
    }

    function testGasCommentTypicalFirst() public {
        _comment(false, 500);
    }

    function testGasCommentMaximumFirst() public {
        _comment(false, 2000);
    }

    function testGasCommentSmallExisting() public {
        _comment(true, 1);
    }

    function testGasCommentTypicalExisting() public {
        _comment(true, 500);
    }

    function testGasCommentMaximumExisting() public {
        _comment(true, 2000);
    }

    function _create(uint256 titleLength, uint256 bodyLength) private {
        vm.pauseGasMetering();
        string memory title = filled(titleLength);
        string memory body = filled(bodyLength);
        Docket target = fresh;
        vm.resumeGasMetering();
        target.createIdea(title, body);
    }

    function _comment(bool subsequent, uint256 bodyLength) private {
        vm.pauseGasMetering();
        string memory body = filled(bodyLength);
        Docket target = subsequent ? existing : uncommented;
        vm.resumeGasMetering();
        uint256 start = gasleft();
        target.comment(1, body);
        uint256 gasUsed = start - gasleft();
        // Includes external-call overhead. The first 500-byte comment is the costly case.
        if (bodyLength == 500) assert(gasUsed < 50_000);
    }
}
