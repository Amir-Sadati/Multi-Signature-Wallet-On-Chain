// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract MultiSigWalletScript is Script {
    MultiSigWallet public wallet;

    function setUp() public {}

    function run() public {
        address[] memory owners = new address[](3);
        owners[0] = vm.addr(1);
        owners[1] = vm.addr(2);
        owners[2] = vm.addr(3);

        vm.startBroadcast();
        wallet = new MultiSigWallet(owners, 2);
        vm.stopBroadcast();
    }
}
