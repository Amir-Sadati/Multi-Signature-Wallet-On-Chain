// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract MultiSigWallet {
    // --- Errors ---
    error MultiSigWallet__NotOwner();
    error MultiSigWallet__TxDoesNotExist();
    error MultiSigWallet__TxAlreadyExecuted();
    error MultiSigWallet__TxAlreadyConfirmed();
    error MultiSigWallet__OwnersRequired();
    error MultiSigWallet__InvalidNumConfirmations();
    error MultiSigWallet__InvalidOwner();
    error MultiSigWallet__OwnerNotUnique();
    error MultiSigWallet__CannotExecuteTx();
    error MultiSigWallet__TxFailed();
    error MultiSigWallet__TxNotConfirmed();

    // --- Type declarations ---
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }

    // --- State variables ---
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public numConfirmationsRequired;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;
    Transaction[] public transactions;

    // --- Events ---
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);

    // --- Modifiers ---
    modifier onlyOwner() {
        if (!isOwner[msg.sender]) {
            revert MultiSigWallet__NotOwner();
        }
        _;
    }

    modifier txExists(uint256 _txIndex) {
        if (_txIndex >= transactions.length) {
            revert MultiSigWallet__TxDoesNotExist();
        }
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        if (transactions[_txIndex].executed) {
            revert MultiSigWallet__TxAlreadyExecuted();
        }
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        if (isConfirmed[_txIndex][msg.sender]) {
            revert MultiSigWallet__TxAlreadyConfirmed();
        }
        _;
    }

    // --- Functions ---

    // constructor
    constructor(address[] memory _owners, uint256 _numConfirmationsRequired) {
        if (_owners.length == 0) revert MultiSigWallet__OwnersRequired();
        if (
            _numConfirmationsRequired == 0 ||
            _numConfirmationsRequired > _owners.length
        ) {
            revert MultiSigWallet__InvalidNumConfirmations();
        }

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            if (owner == address(0)) revert MultiSigWallet__InvalidOwner();
            if (isOwner[owner]) revert MultiSigWallet__OwnerNotUnique();

            isOwner[owner] = true;
            owners.push(owner);
        }

        numConfirmationsRequired = _numConfirmationsRequired;
    }

    // receive function (if exists)
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    // external
    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) external onlyOwner {
        uint256 txIndex = transactions.length;

        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );

        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }

    function confirmTransaction(
        uint256 _txIndex
    )
        external
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(
        uint256 _txIndex
    ) external onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        if (transaction.numConfirmations < numConfirmationsRequired) {
            revert MultiSigWallet__CannotExecuteTx();
        }

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        if (!success) revert MultiSigWallet__TxFailed();

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(
        uint256 _txIndex
    ) external onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];

        if (!isConfirmed[_txIndex][msg.sender]) {
            revert MultiSigWallet__TxNotConfirmed();
        }

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    // public view functions
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(
        uint256 _txIndex
    )
        public
        view
        txExists(_txIndex)
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
}
