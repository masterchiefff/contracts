// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

interface IPriceFeed {
    function getLatestPrice() external view returns (int);
}

contract P2PLending {
    address[] public stableAssets = [/* your contract address here */];

    // The minimum and maximum amount of ETH that can be loaned
    uint public constant MIN_LOAN_AMOUNT = 0.1 ether;
    uint public constant MAX_LOAN_AMOUNT = 10 ether;
    // The minimum and maximum interest rate in percentage that can be set for a loan
    uint public constant MIN_INTEREST_RATE = 1;
    uint public constant MAX_INTEREST_RATE = 10;

    // LTV ratios for different asset types (in percentage)
    uint public constant VOLATILE_ASSET_LTV = 60;  // 60% LTV for volatile assets
    uint public constant STABLE_ASSET_LTV = 80;   // 80% LTV for stable assets

    IPriceFeed public priceFeed;

    struct Loan {
        uint amount;
        uint interest;
        uint duration;
        uint repaymentAmount;
        uint fundingDeadline;
        address borrower;
        address payable lender;
        bool active;
        bool repaid;
        uint collateralAmount;
        address collateralAsset;
    }

    mapping(uint => Loan) public loans;
    uint public loanCount;

    event LoanCreated(
        uint loanId,
        uint amount,
        uint interest,
        uint duration,
        uint fundingDeadline,
        address borrower,
        address lender,
        uint collateralAmount,
        address collateralAsset
    );
    event LoanFunded(uint loanId, address funder, uint amount);
    event LoanRepaid(uint loanId, uint amount);

    modifier onlyActiveLoan(uint _loanId) {
        require(loans[_loanId].active, "Loan is not active");
        _;
    }

    modifier onlyBorrower(uint _loanId) {
        require(
            msg.sender == loans[_loanId].borrower,
            "Only the borrower can perform this action"
        );
        _;
    }

    modifier onlyCollateralAsset(uint _loanId) {
        require(
            msg.sender == loans[_loanId].collateralAsset,
            "Only the collateral asset can perform this action"
        );
        _;
    }

    constructor(address _priceFeed) {
        priceFeed = IPriceFeed(_priceFeed);
    }

    function createLoan(
    uint _amount,
    uint _interest,
    uint _duration,
    uint _collateralAmount,
    address _collateralAsset
) external payable {
    require(
        _amount >= MIN_LOAN_AMOUNT && _amount <= MAX_LOAN_AMOUNT,
        "Loan amount must be between MIN_LOAN_AMOUNT and MAX_LOAN_AMOUNT"
    );
    require(
        _interest >= MIN_INTEREST_RATE && _interest <= MAX_INTEREST_RATE,
        "Interest rate must be between MIN_INTEREST_RATE and MAX_INTEREST_RATE"
    );
    require(_duration > 0, "Loan duration must be greater than 0");

    // Collateral calculation (Using LTV and stable/volatile asset check)
    uint collateralRequired = calculateCollateral(_amount, _collateralAsset);

    // Check if the borrower has enough collateral in their wallet
    require(msg.sender.balance >= collateralRequired, "Insufficient collateral");

    uint repaymentAmount = _amount + (_amount * _interest) / 100;
    uint fundingDeadline = block.timestamp + 1 days;

    // Create a new loan
    uint loanId = loanCount++;
    Loan storage loan = loans[loanId];
    loan.amount = _amount;
    loan.interest = _interest;
    loan.duration = _duration;
    loan.repaymentAmount = repaymentAmount;
    loan.fundingDeadline = fundingDeadline;
    loan.borrower = msg.sender;
    loan.lender = payable(address(0));
    loan.active = true;
    loan.repaid = false;

    // Store collateral deposit in the contract (transfer collateral from borrower)
    depositCollateral(_collateralAsset, collateralRequired);

    emit LoanCreated(
        loanId,
        _amount,
        _interest,
        _duration,
        fundingDeadline,
        msg.sender,
        address(0)
    );
}

function calculateCollateral(uint _loanAmount, address _collateralAsset) public view returns (uint) {
    // Assuming you have a function to check if the asset is stable or volatile
    uint collateralFactor = isStableAsset(_collateralAsset) ? 80 : 60;
    return (_loanAmount * collateralFactor) / 100;
}

function depositCollateral(address _collateralAsset, uint _collateralAmount) internal {
    // Implement the logic for transferring collateral from borrower
    // You can use ERC20 `transferFrom` for token collateral or use `transfer` for ETH
    require(
        ERC20(_collateralAsset).transferFrom(msg.sender, address(this), _collateralAmount),
        "Collateral transfer failed"
    );
}

function isStableAsset(address _asset) internal pure returns (bool) {
    return contains(stableAssets, _asset);
}

function contains(address[] storage arr, address element) internal view returns(bool){
    for(uint256 i=0;i<arr.length;++i)
        if(arr[i]==element)return true;
}

    function fundLoan(uint _loanId) external payable onlyActiveLoan(_loanId) {
        Loan storage loan = loans[_loanId];
        require(
            msg.sender != loan.borrower,
            "Borrower cannot fund their own loan"
        );
        require(loan.amount == msg.value, "Not enough ETH to fund the loan");
        require(
            block.timestamp <= loan.fundingDeadline,
            "Loan funding deadline has passed"
        );
        payable(address(this)).transfer(msg.value);
        loan.lender = payable(msg.sender);
        loan.active = false;
        emit LoanFunded(_loanId, msg.sender, msg.value);
    }

    function repayLoan(uint _loanId) external payable onlyActiveLoan(_loanId) onlyBorrower(_loanId) {
        require(
            msg.value == loans[_loanId].repaymentAmount,
            "Incorrect repayment amount"
        );
        loans[_loanId].lender.transfer(msg.value);
        loans[_loanId].repaid = true;
        loans[_loanId].active = false;
        emit LoanRepaid(_loanId, msg.value);
    }

    function getLoanInfo(
        uint _loanId
    )
        external
        view
        returns (
            uint amount,
            uint interest,
            uint duration,
            uint repaymentAmount,
            uint fundingDeadline,
            address borrower,
            address lender,
            bool active,
            bool repaid,
            uint collateralAmount,
            address collateralAsset
        )
    {
        Loan storage loan = loans[_loanId];
        return (
            loan.amount,
            loan.interest,
            loan.duration,
            loan.repaymentAmount,
            loan.fundingDeadline,
            loan.borrower,
            loan.lender,
            loan.active,
            loan.repaid,
            loan.collateralAmount,
            loan.collateralAsset
        );
    }

    function calculateCollateral(
        address _collateralAsset,
        uint _collateralAmount,
        uint _loanAmount
    ) public view returns (uint) {
        uint collateralValue;
        if (_collateralAsset == address(0)) {
            collateralValue = _collateralAmount * VOLATILE_ASSET_LTV / 100;
        } else {
            collateralValue = _collateralAmount * STABLE_ASSET_LTV / 100;
        }

        return collateralValue;
    }

    function getFiatToEthRate() public view returns (uint) {
        int price = priceFeed.getLatestPrice();
        require(price > 0, "Invalid price feed");
        return uint(price);
    }

    function withdrawFunds(uint _loanId) external onlyBorrower(_loanId) {
        Loan storage loan = loans[_loanId];
        require(loan.active == false, "Loan must not be active");
        payable(msg.sender).transfer(loan.amount);
    }
}
