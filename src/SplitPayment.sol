// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SplitPayment - immutable payment splitter (OZ PaymentSplitter pattern)
/// @notice No admin, no owner. Payees and shares set at construction, immutable.
contract SplitPayment {
    uint256 public totalShares;
    uint256 public totalReleased;

    address[] private _payees;
    mapping(address => uint256) public shares;
    mapping(address => uint256) public released;

    event PayeeAdded(address account, uint256 shares_);
    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    constructor(address[] memory payees_, uint256[] memory shares_) {
        require(payees_.length == shares_.length, "length mismatch");
        require(payees_.length > 0, "no payees");

        for (uint256 i = 0; i < payees_.length; i++) {
            require(payees_[i] != address(0), "zero address");
            require(shares_[i] > 0, "zero shares");
            require(shares[payees_[i]] == 0, "duplicate payee");

            _payees.push(payees_[i]);
            shares[payees_[i]] = shares_[i];
            totalShares += shares_[i];
            emit PayeeAdded(payees_[i], shares_[i]);
        }
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    function releasable(address account) public view returns (uint256) {
        require(shares[account] > 0, "no shares");
        uint256 totalReceived = address(this).balance + totalReleased;
        uint256 entitled = (totalReceived * shares[account]) / totalShares;
        return entitled - released[account];
    }

    function release(address payable account) external {
        require(shares[account] > 0, "no shares");
        uint256 payment = releasable(account);
        require(payment > 0, "nothing due");

        released[account] += payment;
        totalReleased += payment;

        (bool ok, ) = account.call{value: payment}("");
        require(ok, "transfer failed");
        emit PaymentReleased(account, payment);
    }

    function payeesCount() external view returns (uint256) {
        return _payees.length;
    }

    function payee(uint256 index) external view returns (address) {
        return _payees[index];
    }
}
