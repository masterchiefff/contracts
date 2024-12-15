// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

contract P3rf3ctFlag {

    uint256 private _flag;

    constructor(uint256 flag_) {
        _flag = flag_;
    }

    function setFlag(uint256) public pure returns(bool){
        return true;
    }

}