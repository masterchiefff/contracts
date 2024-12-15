// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PesabitsCollateralManager is ReentrancyGuard {

    address public owner;
    address public escrowWallet;

    enum CollateralType { USDT, USDC, BTC }

    mapping(CollateralType => address) public approvedTokens;

    event CollateralDeposited(address indexed borrower, CollateralType tokenType, uint256 amount);
    event CollateralWithdrawn(address indexed borrower, CollateralType tokenType, uint256 amount);

    struct Collateral {
        uint256 amount;
        CollateralType tokenType;
    }

    mapping(address => Collateral) public borrowerCollateral;

    error InvalidEscrowWallet();
    error InvalidTokenAddress();
    error NoCollateralToWithdraw();
    error NotEnoughCollateral();
    error InsufficientEscrowBalance();

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(address _escrowWallet) {
        require(_escrowWallet != address(0), "Invalid escrow wallet");
        owner = msg.sender;
        escrowWallet = _escrowWallet;
    }

    function setApprovedToken(CollateralType _tokenType, address _tokenAddress) external onlyOwner {
        require(_tokenAddress != address(0), "Invalid token address");
        approvedTokens[_tokenType] = _tokenAddress;
    }

    function depositCollateral(CollateralType _tokenType, uint256 _amount) external nonReentrant {
        require(_amount > 0, "Collateral amount must be greater than zero");

        address tokenAddress = approvedTokens[_tokenType];
        require(tokenAddress != address(0), "Invalid collateral token");

        // Transfer tokens from the borrower to the escrow wallet
        bool success = IERC20(tokenAddress).transferFrom(msg.sender, escrowWallet, _amount);
        require(success, "Token transfer failed");

        // Update the borrower's collateral
        borrowerCollateral[msg.sender] = Collateral({
            amount: _amount,
            tokenType: _tokenType
        });

        emit CollateralDeposited(msg.sender, _tokenType, _amount);
    }

    function withdrawCollateral() external nonReentrant {
        Collateral storage collateralData = borrowerCollateral[msg.sender];
        require(collateralData.amount > 0, "No collateral to withdraw");

        address tokenAddress = approvedTokens[collateralData.tokenType];
        require(tokenAddress != address(0), "Invalid collateral token");

        uint256 amount = collateralData.amount;
        collateralData.amount = 0;

        uint256 escrowBalance = IERC20(tokenAddress).balanceOf(escrowWallet);
        require(escrowBalance >= amount, "Escrow wallet has insufficient balance");

        bool success = IERC20(tokenAddress).transferFrom(escrowWallet, msg.sender, amount);
        require(success, "Token transfer failed");

        emit CollateralWithdrawn(msg.sender, collateralData.tokenType, amount);
    }
}
