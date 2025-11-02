// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title KipuBankV2 - Final (roles, multi-token, Chainlink, pausable, reentrancy)
/// @author Isabel
/// @notice Versión mejorada que implementa control por roles, soporte multi-token (ETH + 2 ERC20),
///         contabilidad interna en USDC (6 decimales), oráculos Chainlink y protecciones de seguridad.
/// @dev Diseñado para entrega del Módulo 3. Usa address(0) para ETH.
contract KipuBankV2_Final {
    /* ========== ERRORS ========== */
    error ZeroAmount();
    error BankCapExceeded(uint256 attempted, uint256 available);
    error ExceedsWithdrawLimit(uint256 requested, uint256 limit);
    error InsufficientBalance(uint256 requested, uint256 available);
    error TransferFailed(address to, uint256 amount);
    error NotOwner();
    error NotAuthorized(address caller);
    error Paused();
    error ReentrantCall();

    /* ========== EVENTS ========== */
    event Deposit(address indexed user, address indexed token, uint256 rawAmount, uint256 usdcAmount, uint256 depositIndex);
    event Withdrawal(address indexed user, uint256 amountUsdc, uint256 withdrawalIndex);
    event ERC20Deposited(address indexed user, address indexed token, uint256 tokenAmount, uint256 usdcAmount);
    event TokenPriceFeedSet(address indexed token, address indexed feed);
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event PausedStateChanged(bool paused);

    /* ========== CONSTANTS & IMMUTABLES ========== */
    uint8 public constant USDC_DECIMALS = 6;

    uint256 public immutable withdrawLimitUsdc; // in USDC units (6 decimals)
    uint256 public immutable bankCapUsdc;       // in USDC units (6 decimals)

    /* ========== STORAGE ========== */
    // tokenBalances[user][token] => raw token balance (token decimals)
    mapping(address => mapping(address => uint256)) public tokenBalances;

    // balancesUSDC[user] => balance in USDC units (6 decimals)
    mapping(address => uint256) public balancesUSDC;
    uint256 public totalUSDCStored;

    uint256 public depositCount;
    uint256 public withdrawalCount;

    /* ========== ORACLES & TOKEN CONFIG ========== */
    AggregatorV3Interface public immutable ethUsdPriceFeed;
    mapping(address => AggregatorV3Interface) public tokenPriceFeed; // token => Chainlink feed
    address public usdcToken; // if set, withdrawals try to send actual USDC tokens

    /* ========== ACCESS CONTROL ========== */
    address public owner;
    bytes32 public constant ROLE_MANAGER = keccak256("ROLE_MANAGER");
    // simple role store: role => account => bool
    mapping(bytes32 => mapping(address => bool)) public roles;

    /* ========== PROTECTIONS ========== */
    bool public paused;
    uint256 private _status; // 1 = not entered, 2 = entered (reentrancy)

    /* ========== MODIFIERS ========== */
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyRole(bytes32 role) {
        if (msg.sender != owner && !roles[role][msg.sender]) revert NotAuthorized(msg.sender);
        _;
    }

    modifier notPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier nonZero(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }

    modifier nonReentrant() {
        if (_status != 1) revert ReentrantCall();
        _status = 2;
        _;
        _status = 1;
    }

    /* ========== CONSTRUCTOR ========== */
    /// @param _withdrawLimitUsdc withdraw limit in USDC units (6 decimals)
    /// @param _bankCapUsdc bank cap in USDC units (6 decimals)
    /// @param _ethUsdPriceFeed Chainlink ETH/USD feed address (network-specific)
    constructor(
        uint256 _withdrawLimitUsdc,
        uint256 _bankCapUsdc,
        address _ethUsdPriceFeed
    ) {
        if (_withdrawLimitUsdc == 0 || _bankCapUsdc == 0) revert ZeroAmount();
        withdrawLimitUsdc = _withdrawLimitUsdc;
        bankCapUsdc = _bankCapUsdc;
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);

        owner = msg.sender;
        _status = 1;
        // owner implicitly has manager role
        roles[ROLE_MANAGER][owner] = true;
    }

    /* ========== ADMIN / ROLES ========== */

    /// @notice Grant a role to an account (onlyOwner)
    function grantRole(bytes32 role, address account) external onlyOwner {
        roles[role][account] = true;
        emit RoleGranted(role, account, msg.sender);
    }

    /// @notice Revoke a role from an account (onlyOwner)
    function revokeRole(bytes32 role, address account) external onlyOwner {
        roles[role][account] = false;
        emit RoleRevoked(role, account, msg.sender);
    }

    /// @notice Transfer ownership (onlyOwner)
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero address");
        emit OwnerChanged(owner, newOwner);
        owner = newOwner;
        // give manager role to new owner
        roles[ROLE_MANAGER][newOwner] = true;
    }

    /// @notice Set paused state (only manager or owner)
    function setPaused(bool _paused) external onlyRole(ROLE_MANAGER) {
        paused = _paused;
        emit PausedStateChanged(_paused);
    }

    /* ========== CONFIGURATION ========== */

    /// @notice Set USDC token address for withdrawals
    function setUSDC(address _usdc) external onlyRole(ROLE_MANAGER) {
        usdcToken = _usdc;
    }

    /// @notice Register a Chainlink feed for a token (token/USD)
    function setTokenPriceFeed(address token, address feed) external onlyRole(ROLE_MANAGER) {
        tokenPriceFeed[token] = AggregatorV3Interface(feed);
        emit TokenPriceFeedSet(token, feed);
    }

    /* ========== DEPOSITS (ETH + ERC20) ========== */

    /// @notice Deposit native ETH (address(0) used for ETH)
    function depositETH() external payable nonReentrant notPaused nonZero(msg.value) {
        // Convert ETH (wei) -> USDC (6 decimals)
        uint256 usdcAmount = _toUSDC(address(0), msg.value);

        if (totalUSDCStored + usdcAmount > bankCapUsdc) {
            revert BankCapExceeded(totalUSDCStored + usdcAmount, bankCapUsdc - totalUSDCStored);
        }

        // Effects
        balancesUSDC[msg.sender] += usdcAmount;
        totalUSDCStored += usdcAmount;
        depositCount += 1;

        // Track raw ETH deposit
        tokenBalances[msg.sender][address(0)] += msg.value;

        emit Deposit(msg.sender, address(0), msg.value, usdcAmount, depositCount);
    }

    /// @notice Deposit USDC token directly (user must approve)
    /// @param amount amount in USDC token decimals (6)
    function depositUSDC(uint256 amount) external nonReentrant notPaused nonZero(amount) {
        require(usdcToken != address(0), "USDC not configured");
        bool ok = IERC20(usdcToken).transferFrom(msg.sender, address(this), amount);
        require(ok, "USDC transfer failed");

        if (totalUSDCStored + amount > bankCapUsdc) {
            revert BankCapExceeded(totalUSDCStored + amount, bankCapUsdc - totalUSDCStored);
        }

        balancesUSDC[msg.sender] += amount;
        totalUSDCStored += amount;
        depositCount += 1;
        tokenBalances[msg.sender][usdcToken] += amount;

        emit Deposit(msg.sender, usdcToken, amount, amount, depositCount);
    }

    /// @notice Deposit an ERC20 token (owner must register price feed for the token)
    /// @param token ERC20 token address
    /// @param amount token amount in token decimals
    function depositERC20(address token, uint256 amount) external nonReentrant notPaused nonZero(amount) {
        require(token != address(0), "use depositETH for native");
        bool pulled = IERC20(token).transferFrom(msg.sender, address(this), amount);
        require(pulled, "transferFrom failed");

        // Convert token to USDC via price feed
        uint256 usdcAmount = _toUSDC(token, amount);

        if (totalUSDCStored + usdcAmount > bankCapUsdc) {
            // revert to avoid partial state
            revert BankCapExceeded(totalUSDCStored + usdcAmount, bankCapUsdc - totalUSDCStored);
        }

        // Effects
        balancesUSDC[msg.sender] += usdcAmount;
        totalUSDCStored += usdcAmount;
        depositCount += 1;
        tokenBalances[msg.sender][token] += amount;

        emit ERC20Deposited(msg.sender, token, amount, usdcAmount);
        emit Deposit(msg.sender, token, amount, usdcAmount, depositCount);
    }

    /* ========== WITHDRAWALS ========== */

    /// @notice Withdraw balance in USDC units (6 decimals). Try to send USDC token if configured, otherwise send ETH equivalent.
    /// @param amountUsdc amount in USDC units (6 decimals)
    function withdrawUSDC(uint256 amountUsdc) external nonReentrant notPaused nonZero(amountUsdc) {
        if (amountUsdc > withdrawLimitUsdc) revert ExceedsWithdrawLimit(amountUsdc, withdrawLimitUsdc);
        uint256 bal = balancesUSDC[msg.sender];
        if (amountUsdc > bal) revert InsufficientBalance(amountUsdc, bal);

        // Effects
        balancesUSDC[msg.sender] = bal - amountUsdc;
        totalUSDCStored -= amountUsdc;
        withdrawalCount += 1;

        // Interactions: try to transfer USDC token if configured
        if (usdcToken != address(0)) {
            bool ok = IERC20(usdcToken).transfer(msg.sender, amountUsdc);
            if (!ok) revert TransferFailed(msg.sender, amountUsdc);
        } else {
            // Convert USDC to ETH (best-effort) and send
            uint256 ethWei = _fromUSDCToETH(amountUsdc);
            (bool sent, ) = msg.sender.call{value: ethWei}("");
            if (!sent) revert TransferFailed(msg.sender, ethWei);
        }

        emit Withdrawal(msg.sender, amountUsdc, withdrawalCount);
    }

    /* ========== VIEWS & HELPERS ========== */

    /// @notice Get user's USDC internal balance (6 decimals)
    function getBalanceUSDC(address user) external view returns (uint256) {
        return balancesUSDC[user];
    }

    /// @notice Get raw token balance for user and token
    function getTokenBalance(address user, address token) external view returns (uint256) {
        return tokenBalances[user][token];
    }

    /// @notice Convert token or ETH amount into USDC units (6 decimals) using Chainlink feeds
    /// @param token token address (address(0) for ETH)
    /// @param amount amount in token decimals (wei for ETH)
    /// @return usdcAmount amount in USDC units (6 decimals)
    function _toUSDC(address token, uint256 amount) internal view returns (uint256 usdcAmount) {
        if (token == address(0)) {
            // ETH -> USD (price has feed decimals, often 8)
            (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
            uint256 uprice = uint256(price); // feed decimals
            // usd6 = ethWei * price / 1e20 (wei 1e18, price 1e8, target 1e6 => divide by 1e(18+8-6)=1e20)
            usdcAmount = (amount * uprice) / 1e20;
            return usdcAmount;
        } else {
            AggregatorV3Interface feed = tokenPriceFeed[token];
            require(address(feed) != address(0), "no feed for token");
            (, int256 price, , , ) = feed.latestRoundData();
            uint256 uprice = uint256(price);
            uint8 tokenDecimals = IERC20Metadata(token).decimals();
            uint8 feedDecimals = feed.decimals();
            // denomExp = tokenDecimals + feedDecimals - USDC_DECIMALS
            uint256 denomExp = uint256(tokenDecimals) + uint256(feedDecimals) - uint256(USDC_DECIMALS);
            uint256 denom = 10 ** denomExp;
            usdcAmount = (amount * uprice) / denom;
            return usdcAmount;
        }
    }

    /// @notice Convert USDC(6) back to ETH wei using ETH/USD feed
    function _fromUSDCToETH(uint256 usdcAmount) internal view returns (uint256 ethWei) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        uint256 uprice = uint256(price);
        // ethWei = usdc6 * 1e20 / price (inverse of _toUSDC)
        ethWei = (usdcAmount * 1e20) / uprice;
    }

    /* ========== FALLBACKS ========== */
    receive() external payable {
        depositETH();
    }

    /* ========== INTERFACES ========== */
    interface AggregatorV3Interface {
        function decimals() external view returns (uint8);
        function latestRoundData() external view returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
    }

    interface IERC20 {
        function transferFrom(address from, address to, uint256 amount) external returns (bool);
        function transfer(address to, uint256 amount) external returns (bool);
    }

    interface IERC20Metadata {
        function decimals() external view returns (uint8);
    }
}

