// SPDX-License-Identifier: MIT
pragma solidity >=0.4.0 <0.9.0;

contract MultiSignatureWallet {
    address[] public owners;
    uint256 public confirmations;

    // transaction struct
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    // mapping from transaction id => owner => bool
    mapping(uint256 => mapping(address => bool)) public confirmed;
    mapping(address => bool) public isOwner;

    // array of transaction struct
    Transaction[] public transactions;

    // Modifiers

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier transactionExists(uint256 _id) {
        require(_id < transactions.length, "transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _id) {
        require(!transactions[_id].executed, "transaction already executed");
        _;
    }

    modifier notConfirmed(uint256 _id) {
        require(!confirmed[_id][msg.sender], "transaction already confirmed");
        _;
    }

    // Constructor
    constructor(address[] memory _owners, uint256 _confirmations) {
        require(_owners.length > 0, "owners required");
        require(
            _confirmations > 0 && _confirmations <= _owners.length,
            "invalid number of required confirmations"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        confirmations = _confirmations;
    }

    // fallback function for empty calldata
    receive() external payable {}

    // Functions

    function proposeTransaction(address _to, bytes memory _data)
        public
        payable
        onlyOwner
    {
        transactions.push(Transaction(_to, msg.value, _data, false, 0));
        uint256 id = transactions.length - 1;
    }

    function confirmTransaction(uint256 _id)
        public
        onlyOwner
        transactionExists(_id)
        notExecuted(_id)
        notConfirmed(_id)
    {
        Transaction storage transaction = transactions[_id];
        transaction.confirmations += 1;
        confirmed[_id][msg.sender] = true;
    }

    function executeTransaction(uint256 _id)
        public
        onlyOwner
        transactionExists(_id)
        notExecuted(_id)
    {
        Transaction storage transaction = transactions[_id];

        require(
            transaction.confirmations >= confirmations,
            "cannot execute transaction"
        );

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "transaction failed");
    }

    function cancelConfirmation(uint256 _id)
        public
        onlyOwner
        transactionExists(_id)
        notExecuted(_id)
    {
        Transaction storage transaction = transactions[_id];

        require(confirmed[_id][msg.sender], "transaction not confirmed");

        transaction.confirmations -= 1;
        confirmed[_id][msg.sender] = false;
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 _id)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 confirmations
        )
    {
        Transaction storage transaction = transactions[_id];

        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.confirmations
        );
    }
}
