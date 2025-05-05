// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet public wallet;
    address[] public owners;
    uint256 public constant NUM_CONFIRMATIONS_REQUIRED = 2;

    address public owner1 = makeAddr("owner1");
    address public owner2 = makeAddr("owner2");
    address public owner3 = makeAddr("owner3");
    address public nonOwner = makeAddr("nonOwner");
    address public recipient = makeAddr("recipient");

    function setUp() public {
        owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        wallet = new MultiSigWallet(owners, NUM_CONFIRMATIONS_REQUIRED);
    }

    function test_Constructor() public view {
        address[] memory walletOwners = wallet.getOwners();
        assertEq(walletOwners.length, 3);
        assertEq(walletOwners[0], owner1);
        assertEq(walletOwners[1], owner2);
        assertEq(walletOwners[2], owner3);

        assertTrue(wallet.isOwner(owner1));
        assertTrue(wallet.isOwner(owner2));
        assertTrue(wallet.isOwner(owner3));
        assertFalse(wallet.isOwner(nonOwner));

        assertEq(wallet.numConfirmationsRequired(), NUM_CONFIRMATIONS_REQUIRED);
    }

    function test_Constructor_ZeroOwners() public {
        address[] memory emptyOwners = new address[](0);
        vm.expectRevert(MultiSigWallet.MultiSigWallet__OwnersRequired.selector);
        new MultiSigWallet(emptyOwners, 1);
    }

    function test_Constructor_InvalidNumConfirmations() public {
        vm.expectRevert(
            MultiSigWallet.MultiSigWallet__InvalidNumConfirmations.selector
        );
        new MultiSigWallet(owners, 0);

        vm.expectRevert(
            MultiSigWallet.MultiSigWallet__InvalidNumConfirmations.selector
        );
        console2.log("owners count is ", owners.length);
        new MultiSigWallet(owners, 4);
    }

    function test_Receive() public {
        uint256 amount = 1 ether;
        vm.deal(address(this), amount);

        (bool success, ) = address(wallet).call{value: amount}("");
        assertTrue(success);
        assertEq(address(wallet).balance, amount);
    }

    function test_SubmitTransaction() public {
        vm.startPrank(owner1);

        bytes memory data = abi.encodeWithSignature(
            "transfer(address,uint256)",
            recipient,
            1 ether
        );
        vm.expectEmit(true, true, true, true);
        emit MultiSigWallet.SubmitTransaction(
            owner1,
            0,
            recipient,
            1 ether,
            data
        );

        wallet.submitTransaction(recipient, 1 ether, data);

        (
            address to,
            uint256 value,
            bytes memory txData,
            bool executed,
            uint256 numConfirmations
        ) = wallet.getTransaction(0);
        assertEq(to, recipient);
        assertEq(value, 1 ether);
        assertEq(txData, data);
        assertFalse(executed);
        assertEq(numConfirmations, 0);

        vm.stopPrank();
    }

    function test_SubmitTransaction_NotOwner() public {
        vm.startPrank(nonOwner);
        vm.expectRevert(MultiSigWallet.MultiSigWallet__NotOwner.selector);
        wallet.submitTransaction(recipient, 1 ether, "");
        vm.stopPrank();
    }

    function test_ConfirmTransaction() public {
        vm.startPrank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");
        vm.stopPrank();

        vm.startPrank(owner2);
        vm.expectEmit(true, true, false, false);
        emit MultiSigWallet.ConfirmTransaction(owner2, 0);
        wallet.confirmTransaction(0);

        (, , , bool executed, uint256 numConfirmations) = wallet.getTransaction(
            0
        );
        assertFalse(executed);
        assertEq(numConfirmations, 1);
        assertTrue(wallet.isConfirmed(0, owner2));
        vm.stopPrank();
    }

    function test_ConfirmTransaction_NotOwner() public {
        vm.startPrank(nonOwner);
        vm.expectRevert(MultiSigWallet.MultiSigWallet__NotOwner.selector);
        wallet.confirmTransaction(0);
        vm.stopPrank();
    }

    function test_ConfirmTransaction_AlreadyConfirmed() public {
        vm.startPrank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");
        wallet.confirmTransaction(0);
        vm.stopPrank();

        vm.startPrank(owner1);
        vm.expectRevert(
            MultiSigWallet.MultiSigWallet__TxAlreadyConfirmed.selector
        );
        wallet.confirmTransaction(0);
        vm.stopPrank();
    }

    function test_ExecuteTransaction() public {
        vm.startPrank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");
        vm.stopPrank();

        vm.startPrank(owner2);
        wallet.confirmTransaction(0);
        vm.stopPrank();

        vm.startPrank(owner3);
        wallet.confirmTransaction(0);
        vm.stopPrank();

        vm.deal(address(wallet), 1 ether);
        vm.startPrank(owner1);
        vm.expectEmit(true, true, false, false);
        emit MultiSigWallet.ExecuteTransaction(owner1, 0);
        wallet.executeTransaction(0);

        (, , , bool executed, ) = wallet.getTransaction(0);
        assertTrue(executed);
        assertEq(recipient.balance, 1 ether);
        vm.stopPrank();
    }

    function test_ExecuteTransaction_NotEnoughConfirmations() public {
        vm.startPrank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");
        vm.stopPrank();

        vm.startPrank(owner2);
        wallet.confirmTransaction(0);
        vm.stopPrank();

        vm.startPrank(owner1);
        vm.expectRevert(
            MultiSigWallet.MultiSigWallet__CannotExecuteTx.selector
        );
        wallet.executeTransaction(0);
        vm.stopPrank();
    }

    function test_RevokeConfirmation() public {
        vm.startPrank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");
        wallet.confirmTransaction(0);
        vm.stopPrank();

        vm.startPrank(owner1);
        vm.expectEmit(true, true, false, false);
        emit MultiSigWallet.RevokeConfirmation(owner1, 0);
        wallet.revokeConfirmation(0);

        (, , , bool executed, uint256 numConfirmations) = wallet.getTransaction(
            0
        );
        assertFalse(executed);
        assertEq(numConfirmations, 0);
        assertFalse(wallet.isConfirmed(0, owner1));
        vm.stopPrank();
    }

    function test_RevokeConfirmation_NotConfirmed() public {
        vm.startPrank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");
        vm.stopPrank();

        vm.startPrank(owner2);
        vm.expectRevert(MultiSigWallet.MultiSigWallet__TxNotConfirmed.selector);
        wallet.revokeConfirmation(0);
        vm.stopPrank();
    }

    function test_GetTransactionCount() public {
        assertEq(wallet.getTransactionCount(), 0);

        vm.startPrank(owner1);
        wallet.submitTransaction(recipient, 1 ether, "");
        assertEq(wallet.getTransactionCount(), 1);
        vm.stopPrank();
    }

    function test_GetTransaction() public {
        bytes memory data = abi.encodeWithSignature(
            "transfer(address,uint256)",
            recipient,
            1 ether
        );

        vm.startPrank(owner1);
        wallet.submitTransaction(recipient, 1 ether, data);

        (
            address to,
            uint256 value,
            bytes memory txData,
            bool executed,
            uint256 numConfirmations
        ) = wallet.getTransaction(0);
        assertEq(to, recipient);
        assertEq(value, 1 ether);
        assertEq(txData, data);
        assertFalse(executed);
        assertEq(numConfirmations, 0);
        vm.stopPrank();
    }

    function test_GetTransaction_InvalidIndex() public {
        vm.expectRevert(MultiSigWallet.MultiSigWallet__TxDoesNotExist.selector);
        wallet.getTransaction(0);
    }
}
